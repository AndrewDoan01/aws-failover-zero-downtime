import json
import logging
import os

import boto3


logger = logging.getLogger()
logger.setLevel(logging.INFO)


FAILOVER_KEYWORDS = (
    "failover",
    "failure",
    "unavailable",
    "availability",
    "recovery",
    "shutdown",
    "stopped",
)


def _extract_message(event):
    if "Records" in event:
        records = event.get("Records", [])
        if records:
            sns_payload = records[0].get("Sns", {})
            return sns_payload.get("Message", "")

    return json.dumps(event)


def _should_promote(message):
    text = message.lower()
    return any(keyword in text for keyword in FAILOVER_KEYWORDS)


def _is_already_promoted(rds_client, secondary_db_identifier):
    response = rds_client.describe_db_instances(DBInstanceIdentifier=secondary_db_identifier)
    db_instance = response["DBInstances"][0]
    return not db_instance.get("ReadReplicaSourceDBInstanceIdentifier")


def handler(event, context):
    message = _extract_message(event)
    logger.info("Received failover event: %s", message)

    if not _should_promote(message):
        return {
            "status": "ignored",
            "reason": "event did not contain failover keywords",
        }

    secondary_region = os.environ["SECONDARY_REGION"]
    dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
    backup_retention_days = int(os.environ.get("BACKUP_RETENTION_DAYS", "7"))

    primary_db = os.environ.get("PRIMARY_DB_IDENTIFIER")
    secondary_db = os.environ.get("SECONDARY_DB_IDENTIFIER")
    primary_postgres_db = os.environ.get("PRIMARY_POSTGRES_DB_IDENTIFIER")
    secondary_postgres_db = os.environ.get("SECONDARY_POSTGRES_DB_IDENTIFIER")

    to_promote = []
    
    # Parse event message to check source
    source_id = None
    try:
        event_data = json.loads(message)
        source_id = event_data.get("Source ID")
    except Exception:
        pass

    if source_id:
        if primary_db and source_id == primary_db:
            if secondary_db:
                to_promote.append(secondary_db)
        elif primary_postgres_db and source_id == primary_postgres_db:
            if secondary_postgres_db:
                to_promote.append(secondary_postgres_db)
        else:
            # Ambiguous/unrecognized source but matches failover event, promote both to be safe
            if secondary_db:
                to_promote.append(secondary_db)
            if secondary_postgres_db:
                to_promote.append(secondary_postgres_db)
    else:
        # Fallback/manual trigger: promote both
        if secondary_db:
            to_promote.append(secondary_db)
        if secondary_postgres_db:
            to_promote.append(secondary_postgres_db)

    if not to_promote:
        return {
            "status": "ignored",
            "reason": "no database identifiers matched to promote",
        }

    rds_client = boto3.client("rds", region_name=secondary_region)
    promoted_statuses = {}

    for db_id in to_promote:
        if _is_already_promoted(rds_client, db_id):
            logger.info("Secondary database %s is already promoted", db_id)
            promoted_statuses[db_id] = "already_promoted"
            continue

        if dry_run:
            logger.info(
                "Dry run enabled; would promote read replica %s in %s",
                db_id,
                secondary_region,
            )
            promoted_statuses[db_id] = "dry_run"
            continue

        response = rds_client.promote_read_replica(
            DBInstanceIdentifier=db_id,
            BackupRetentionPeriod=backup_retention_days,
        )
        logger.info(
            "Promotion requested for replica %s in %s",
            db_id,
            secondary_region,
        )
        promoted_statuses[db_id] = "promotion_requested"

    # Trigger GitHub Actions auto failover workflow via Repository Dispatch API
    github_token = os.environ.get("GITHUB_TOKEN")
    if not github_token or not github_token.strip():
        try:
            ssm_client = boto3.client("ssm", region_name="ap-southeast-1")
            param = ssm_client.get_parameter(Name="/github/token", WithDecryption=True)
            github_token = param["Parameter"]["Value"]
            logger.info("Retrieved GITHUB_TOKEN from SSM Parameter Store (/github/token)")
        except Exception as ssm_err:
            logger.warning("Could not retrieve GITHUB_TOKEN from SSM: %s", str(ssm_err))

    if github_token and github_token.strip():
        import urllib.request
        import json

        url = "https://api.github.com/repos/AndrewDoan01/aws-failover-zero-downtime/dispatches"
        headers = {
            "Authorization": f"Bearer {github_token.strip()}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "User-Agent": "AWS-Lambda-Auto-Failover"
        }
        data = json.dumps({"event_type": "auto-failover-trigger"}).encode("utf-8")
        
        try:
            req = urllib.request.Request(url, data=data, headers=headers, method="POST")
            with urllib.request.urlopen(req) as response_dispatch:
                logger.info("Triggered GitHub Actions failover workflow. Status code: %d", response_dispatch.status)
        except Exception as e:
            logger.error("Failed to trigger GitHub Actions workflow: %s", str(e))
    else:
        logger.warning("GITHUB_TOKEN is not set or empty, skipping GitHub Actions trigger")

    return {
        "status": "completed",
        "results": promoted_statuses,
        "secondary_region": secondary_region,
    }

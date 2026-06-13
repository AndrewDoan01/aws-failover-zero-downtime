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
    secondary_db_identifier = os.environ["SECONDARY_DB_IDENTIFIER"]
    dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
    backup_retention_days = int(os.environ.get("BACKUP_RETENTION_DAYS", "7"))

    rds_client = boto3.client("rds", region_name=secondary_region)

    if _is_already_promoted(rds_client, secondary_db_identifier):
        logger.info("Secondary database %s is already promoted", secondary_db_identifier)
        return {
            "status": "already_promoted",
            "secondary_db_identifier": secondary_db_identifier,
        }

    if dry_run:
        logger.info(
            "Dry run enabled; would promote read replica %s in %s",
            secondary_db_identifier,
            secondary_region,
        )
        return {
            "status": "dry_run",
            "secondary_db_identifier": secondary_db_identifier,
            "secondary_region": secondary_region,
        }

    response = rds_client.promote_read_replica(
        DBInstanceIdentifier=secondary_db_identifier,
        BackupRetentionPeriod=backup_retention_days,
        ApplyImmediately=True,
    )

    logger.info(
        "Promotion requested for replica %s in %s",
        secondary_db_identifier,
        secondary_region,
    )

    # Trigger GitHub Actions auto failover workflow via Repository Dispatch API
    github_token = os.environ.get("GITHUB_TOKEN")
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
        "status": "promotion_requested",
        "secondary_db_identifier": secondary_db_identifier,
        "secondary_region": secondary_region,
        "db_instance_status": response["DBInstance"]["DBInstanceStatus"],
    }

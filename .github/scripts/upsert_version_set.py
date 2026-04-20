#!/usr/bin/env python3
"""Upsert one service entry in deploy/versions/<environment>.json."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def parse_values_files(raw: str) -> list[str] | None:
    """
    Parses the values_files input, which can be either a JSON array string 
    or a comma-separated list of strings.
    """
    text = raw.strip()
    if not text:
        return None

    # Handle the case where the input is a JSON array string (e.g., '["values-prod.yaml", "override.yaml"]')
    if text.startswith("["):
        parsed = json.loads(text)
        if not isinstance(parsed, list) or not all(isinstance(item, str) and item.strip() for item in parsed):
            raise ValueError("values-files JSON must be a non-empty string array")
        return [item.strip() for item in parsed]

    # Handle the case where the input is a simple comma-separated string
    values = [item.strip() for item in text.split(",") if item.strip()]
    return values or None


def load_version_set(path: Path, environment: str) -> dict[str, Any]:
    """
    Loads and validates the existing version set JSON file for the target environment.
    Ensures the file structure matches expected schemas before modifying it.
    """
    if not path.exists():
        raise FileNotFoundError(f"Version file does not exist: {path}")

    data = json.loads(path.read_text(encoding="utf-8"))
    
    # Validation: Ensure the root is a JSON object
    if not isinstance(data, dict):
        raise ValueError("Version file must be a JSON object")

    # Validation: Ensure we are updating the correct environment file
    if data.get("environment") != environment:
        raise ValueError(
            f"Version file environment mismatch: expected '{environment}', got '{data.get('environment')}'"
        )

    # Validation: Ensure the 'services' key exists and is an array
    services = data.get("services")
    if not isinstance(services, list):
        raise ValueError("Version file field 'services' must be an array")

    return data


def build_service_record(args: argparse.Namespace) -> dict[str, Any]:
    """
    Constructs the dictionary payload for a single service based on the parsed CLI arguments.
    This dictates the schema for each item in the 'services' array.
    """
    service: dict[str, Any] = {
        "name": args.service_name,
        "release": args.release,
        "namespace": args.namespace,
        "chart": args.chart,
        "chart_version": args.chart_version,
        "image": {
            "repository": args.image_repository,
            "digest": args.image_digest,
        },
        "release_id": args.release_id,
        "app_commit_sha": args.app_commit_sha,
    }

    # Only attach values_files if they were provided
    values_files = parse_values_files(args.values_files)
    if values_files:
        service["values_files"] = values_files

    # Only attach smoke deployment config if it was provided
    if args.smoke_deployment.strip():
        service["smoke"] = {"deployment": args.smoke_deployment.strip()}

    return service


def upsert_service(data: dict[str, Any], service: dict[str, Any]) -> str:
    """
    Inserts a new service or updates an existing one in the services array.
    Always sorts the array alphabetically by service name to ensure clean Git diffs.
    """
    services = data["services"]
    service_name = service["name"]

    # Iterate through existing services to find a match
    for index, existing in enumerate(services):
        if isinstance(existing, dict) and existing.get("name") == service_name:
            # Match found: Update the existing record
            services[index] = service
            # Sort alphabetically by name to maintain a deterministic file structure
            data["services"] = sorted(services, key=lambda item: item.get("name", ""))
            return "updated"

    # No match found: Append as a new service
    services.append(service)
    # Sort alphabetically by name
    data["services"] = sorted(services, key=lambda item: item.get("name", ""))
    return "added"


def parse_args() -> argparse.Namespace:
    """
    Defines and parses the command-line arguments. 
    These map directly to the inputs passed from the GitHub Actions workflow.
    """
    parser = argparse.ArgumentParser(description="Upsert one service record in version-set file")
    
    # The target environment (must match the filename and internal JSON field)
    parser.add_argument("--environment", required=True, choices=["test", "staging", "prod"])
    # The logical identifier for the application being deployed
    parser.add_argument("--service-name", required=True)
    # Helm release name
    parser.add_argument("--release", required=True)
    # Target Kubernetes namespace
    parser.add_argument("--namespace", required=True)
    # Helm chart reference (repo/chart or path)
    parser.add_argument("--chart", required=True)
    # Specific Helm chart version
    parser.add_argument("--chart-version", required=True)
    # Container image ECR URI
    parser.add_argument("--image-repository", required=True)
    # Immutable SHA256 digest of the image
    parser.add_argument("--image-digest", required=True)
    # Identifier from the upstream CI pipeline
    parser.add_argument("--release-id", required=True)
    # Git commit SHA of the app code
    parser.add_argument("--app-commit-sha", required=True)
    # Optional name for smoke test deployment targets
    parser.add_argument("--smoke-deployment", default="")
    # Optional list/JSON array of Helm values files
    parser.add_argument("--values-files", default="")
    
    return parser.parse_args()


def main() -> int:
    """Main execution flow."""
    args = parse_args()
    
    # Construct the file path (e.g., deploy/versions/staging.json)
    version_file = Path("deploy") / "versions" / f"{args.environment}.json"

    # 1. Load the existing environment state
    data = load_version_set(version_file, args.environment)
    
    # 2. Build the new/updated service data object
    record = build_service_record(args)
    
    # 3. Merge the new record into the state (Insert or Update)
    action = upsert_service(data, record)

    # 4. Write the state back to the file with proper indentation and a trailing newline
    version_file.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    
    print(f"{action}: {record['name']} in {version_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
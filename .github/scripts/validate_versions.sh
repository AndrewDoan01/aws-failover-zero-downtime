#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <test|staging|prod>"
  exit 1
fi

VERSION_FILE="deploy/versions/${ENV_NAME}.json"
SCHEMA_FILE="deploy/schema/version-set.schema.json"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "Version file not found: ${VERSION_FILE}"
  exit 1
fi

npx --yes ajv-cli@5 validate -s "${SCHEMA_FILE}" -d "${VERSION_FILE}" --spec=draft2020

# Ensure service names are unique to avoid accidental overwrite in loops.
DUP_COUNT="$(jq -r '.services | map(.name) | group_by(.) | map(select(length > 1)) | length' "${VERSION_FILE}")"
if [[ "${DUP_COUNT}" != "0" ]]; then
  echo "Duplicate service names detected in ${VERSION_FILE}"
  exit 1
fi

echo "Schema validation passed: ${VERSION_FILE}"

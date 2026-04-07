#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
STATE_FILE=".deploy_state/${ENV_NAME}.json"

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <test|staging|prod>"
  exit 1
fi

if [[ ! -f "${STATE_FILE}" ]]; then
  echo "No deploy state file found (${STATE_FILE}); nothing to rollback"
  exit 0
fi

mapfile -t ENTRIES < <(jq -c 'reverse[]' "${STATE_FILE}")

if [[ "${#ENTRIES[@]}" -eq 0 ]]; then
  echo "Deploy state file is empty; nothing to rollback"
  exit 0
fi

for ENTRY in "${ENTRIES[@]}"; do
  NAME="$(jq -r '.name' <<<"${ENTRY}")"
  RELEASE="$(jq -r '.release' <<<"${ENTRY}")"
  NAMESPACE="$(jq -r '.namespace' <<<"${ENTRY}")"
  PREVIOUS_REVISION="$(jq -r '.previous_revision' <<<"${ENTRY}")"

  if [[ -n "${PREVIOUS_REVISION}" ]]; then
    echo "Rolling back ${NAME} (${RELEASE}) to revision ${PREVIOUS_REVISION}"
    helm rollback "${RELEASE}" "${PREVIOUS_REVISION}" -n "${NAMESPACE}" --wait --timeout 5m
  else
    echo "No previous revision for ${NAME}; skipping rollback"
  fi
done

echo "Rollback process finished for ${ENV_NAME}"

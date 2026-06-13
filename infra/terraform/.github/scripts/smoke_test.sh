#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
VERSION_FILE="deploy/versions/${ENV_NAME}.json"

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <test|staging|prod>"
  exit 1
fi

mapfile -t SERVICES < <(jq -c '.services[]' "${VERSION_FILE}")

if [[ "${#SERVICES[@]}" -eq 0 ]]; then
  echo "No services to smoke test in ${VERSION_FILE}"
  exit 0
fi

for SERVICE in "${SERVICES[@]}"; do
  NAME="$(jq -r '.name' <<<"${SERVICE}")"
  NAMESPACE="$(jq -r '.namespace' <<<"${SERVICE}")"
  DEPLOYMENT="$(jq -r '.smoke.deployment // .release' <<<"${SERVICE}")"

  echo "Smoke test rollout for ${NAME}: deployment/${DEPLOYMENT}"
  kubectl rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=180s
done

echo "Smoke tests passed for ${ENV_NAME}"

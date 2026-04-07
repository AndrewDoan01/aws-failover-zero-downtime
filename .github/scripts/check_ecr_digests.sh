#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
VERSION_FILE="deploy/versions/${ENV_NAME}.json"

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <test|staging|prod>"
  exit 1
fi

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "Version file not found: ${VERSION_FILE}"
  exit 1
fi

mapfile -t SERVICES < <(jq -c '.services[]' "${VERSION_FILE}")

if [[ "${#SERVICES[@]}" -eq 0 ]]; then
  echo "No services defined in ${VERSION_FILE}; skipping digest checks"
  exit 0
fi

for SERVICE in "${SERVICES[@]}"; do
  NAME="$(jq -r '.name' <<<"${SERVICE}")"
  REPO_URI="$(jq -r '.image.repository' <<<"${SERVICE}")"
  DIGEST="$(jq -r '.image.digest' <<<"${SERVICE}")"

  if [[ "${REPO_URI}" =~ ^([0-9]{12})\.dkr\.ecr\.([a-z0-9-]+)\.amazonaws\.com\/(.+)$ ]]; then
    REGISTRY_ID="${BASH_REMATCH[1]}"
    REGION="${BASH_REMATCH[2]}"
    REPOSITORY_NAME="${BASH_REMATCH[3]}"
  else
    echo "Invalid ECR repository format for ${NAME}: ${REPO_URI}"
    exit 1
  fi

  echo "Checking digest for ${NAME}: ${DIGEST}"
  aws ecr describe-images \
    --region "${REGION}" \
    --registry-id "${REGISTRY_ID}" \
    --repository-name "${REPOSITORY_NAME}" \
    --image-ids imageDigest="${DIGEST}" \
    --query 'imageDetails[0].imageDigest' \
    --output text >/dev/null

done

echo "ECR digest checks passed for ${VERSION_FILE}"

#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
VERSION_FILE="deploy/versions/${ENV_NAME}.json"
STATE_FILE=".deploy_state/${ENV_NAME}.json"

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <test|staging|prod>"
  exit 1
fi

mkdir -p .deploy_state
printf '[]' > "${STATE_FILE}"

mapfile -t SERVICES < <(jq -c '.services[]' "${VERSION_FILE}")

if [[ "${#SERVICES[@]}" -eq 0 ]]; then
  echo "No services to deploy in ${VERSION_FILE}"
  exit 0
fi

for SERVICE in "${SERVICES[@]}"; do
  NAME="$(jq -r '.name' <<<"${SERVICE}")"
  RELEASE="$(jq -r '.release' <<<"${SERVICE}")"
  NAMESPACE="$(jq -r '.namespace' <<<"${SERVICE}")"
  CHART="$(jq -r '.chart' <<<"${SERVICE}")"
  CHART_VERSION="$(jq -r '.chart_version' <<<"${SERVICE}")"
  REPOSITORY="$(jq -r '.image.repository' <<<"${SERVICE}")"
  DIGEST="$(jq -r '.image.digest' <<<"${SERVICE}")"
  RELEASE_ID="$(jq -r '.release_id' <<<"${SERVICE}")"

  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

  PREVIOUS_REVISION="$(helm history "${RELEASE}" -n "${NAMESPACE}" -o json 2>/dev/null || echo "[]")"
  PREVIOUS_REVISION="$(jq -r 'if length > 0 then .[-1].revision else empty end' <<<"${PREVIOUS_REVISION}" || echo "")"

  echo "Rendering manifest for ${NAME}"
  RENDER_ARGS=(
    template
    "${RELEASE}"
    "${CHART}"
    --namespace "${NAMESPACE}"
    --version "${CHART_VERSION}"
  )

  # Only pin image for ECR-sourced services; Helm meta-charts manage images internally
  if [[ "${REPOSITORY}" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com\/.+ ]]; then
    RENDER_ARGS+=(
      --set-string "image.repository=${REPOSITORY}"
      --set-string "image.tag=${RELEASE_ID}"
      --set-string "image.digest=${DIGEST}"
    )
  fi

  while IFS= read -r VALUE_FILE; do
    [[ -z "${VALUE_FILE}" ]] && continue
    RENDER_ARGS+=(--values "${VALUE_FILE}")
  done < <(jq -r '.values_files[]? // empty' <<<"${SERVICE}")

  helm "${RENDER_ARGS[@]}" > ".deploy_state/${ENV_NAME}-${NAME}-rendered.yaml"

  echo "Deploying ${NAME}"
  UPGRADE_ARGS=(
    upgrade
    --install
    "${RELEASE}"
    "${CHART}"
    --namespace "${NAMESPACE}"
    --version "${CHART_VERSION}"
    --wait
    --timeout 5m
  )

  # Only pin image for ECR-sourced services; Helm meta-charts manage images internally
  if [[ "${REPOSITORY}" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com\/.+ ]]; then
    UPGRADE_ARGS+=(
      --set-string "image.repository=${REPOSITORY}"
      --set-string "image.tag=${RELEASE_ID}"
      --set-string "image.digest=${DIGEST}"
    )
  fi

  while IFS= read -r VALUE_FILE; do
    [[ -z "${VALUE_FILE}" ]] && continue
    UPGRADE_ARGS+=(--values "${VALUE_FILE}")
  done < <(jq -r '.values_files[]? // empty' <<<"${SERVICE}")

  helm "${UPGRADE_ARGS[@]}"

  TMP_FILE="$(mktemp)"
  jq \
    --arg name "${NAME}" \
    --arg release "${RELEASE}" \
    --arg namespace "${NAMESPACE}" \
    --arg prev "${PREVIOUS_REVISION}" \
    '. += [{"name": $name, "release": $release, "namespace": $namespace, "previous_revision": $prev}]' \
    "${STATE_FILE}" > "${TMP_FILE}"
  mv "${TMP_FILE}" "${STATE_FILE}"
done

echo "Helm deploy completed for ${ENV_NAME}"

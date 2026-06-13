#!/usr/bin/env bash
set -euo pipefail

REGION=${1:-ap-southeast-1}
CLUSTER=${2:-eks-ap-southeast-1}
NAMESPACE=${3:-retail-store-sample-prod}
TG_NAME=${4:-aws-ha-zero-downtime-primary-tg}

echo "Updating kubeconfig for $CLUSTER in $REGION..."
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

echo "Retrieving Target Group ARN..."
TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$TG_NAME" --query "TargetGroups[0].TargetGroupArn" --output text)
if [ -z "$TG_ARN" ] || [ "$TG_ARN" == "None" ]; then
  echo "Target group $TG_NAME not found in region $REGION."
  exit 1
fi
echo "Target Group ARN: $TG_ARN"

echo "Retrieving Pod IPs..."
POD_IPS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=retail-store-sample-app -o jsonpath='{.items[*].status.podIP}')
if [ -z "$POD_IPS" ]; then
  echo "No pods found in namespace $NAMESPACE."
  exit 0
fi
echo "Found Pod IPs: $POD_IPS"

TARGETS=""
for IP in $POD_IPS; do
  TARGETS+="Id=$IP,Port=8080 "
done

echo "Registering targets: $TARGETS"
aws elbv2 register-targets --region "$REGION" --target-group-arn "$TG_ARN" --targets $TARGETS
echo "Successfully registered targets!"

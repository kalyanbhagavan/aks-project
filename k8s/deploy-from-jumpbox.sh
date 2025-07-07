#!/bin/bash
set -e

# Usage: ./deploy-from-jumpbox.sh <ACR_NAME>

if [ -z "$1" ]; then
  echo "Usage: $0 <ACR_NAME>"
  exit 1
fi

ACR_NAME=$1

# Replace <ACR_NAME> in deployment.yaml with actual value
tmpfile=$(mktemp)
sed "s|<ACR_NAME>|$ACR_NAME|g" deployment.yaml > $tmpfile

# Apply manifests
kubectl apply -f $tmpfile
kubectl apply -f service.yaml
kubectl apply -f rbac.yaml
kubectl apply -f azure-files-secret.yaml
kubectl apply -f configmap-static-assets.yaml

rm $tmpfile

echo "All manifests applied."
#!/bin/bash

# Uninstall Teable

set -e

NAMESPACE="${1:-teable}"

echo "Uninstalling Teable from namespace: $NAMESPACE"

# Delete resources in reverse order
echo "Deleting Deployment..."
kubectl delete -f deployment.yaml --ignore-not-found=true

echo "Deleting Service..."
kubectl delete -f service.yaml --ignore-not-found=true

echo "Deleting ServiceAccount..."
kubectl delete -f serviceaccount.yaml --ignore-not-found=true

echo "Deleting Secret..."
kubectl delete -f secret.yaml --ignore-not-found=true

echo "Deleting ConfigMap..."
kubectl delete -f configmap.yaml --ignore-not-found=true

echo "Deleting Namespace..."
kubectl delete -f namespace.yaml --ignore-not-found=true

echo "Uninstallation completed!"

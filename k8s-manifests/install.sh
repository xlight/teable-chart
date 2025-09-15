#!/bin/bash

# Install Teable using generated manifests

set -e

NAMESPACE="${1:-teable}"

echo "Installing Teable in namespace: $NAMESPACE"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Apply manifests in order
echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Creating ConfigMap..."
kubectl apply -f configmap.yaml

echo "Creating Secret..."
kubectl apply -f secret.yaml

echo "Creating ServiceAccount..."
kubectl apply -f serviceaccount.yaml

echo "Creating Service..."
kubectl apply -f service.yaml

echo "Creating Deployment..."
kubectl apply -f deployment.yaml

echo "Installation completed!"
echo ""
echo "To check status:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "To access the application:"
echo "  kubectl port-forward svc/teable 8080:3000 -n $NAMESPACE"
echo "  Then visit: http://localhost:8080"
echo ""
echo "To view logs:"
echo "  kubectl logs -l app.kubernetes.io/name=teable -n $NAMESPACE"

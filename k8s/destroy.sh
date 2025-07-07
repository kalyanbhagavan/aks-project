#!/bin/bash

# Simple Destroy Script for AKS
# This script removes the nginx demo application

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[DESTROY]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Starting cleanup of nginx demo app..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    exit 1
fi

print_status "Connected to cluster: $(kubectl config current-context)"

# Confirm deletion
read -p "Are you sure you want to delete the nginx demo app? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deletion cancelled"
    exit 0
fi

# Delete resources in reverse order
print_status "Deleting Ingress..."
kubectl delete ingress nginx-demo-ingress --ignore-not-found=true

print_status "Deleting Ingress Controller..."
kubectl delete -f ingress-controller.yaml --ignore-not-found=true

print_status "Deleting Deployment..."
kubectl delete deployment nginx-demo --ignore-not-found=true

print_status "Deleting Service..."
kubectl delete service nginx-demo-service --ignore-not-found=true

print_status "Deleting RBAC resources..."
kubectl delete rolebinding dev-team-binding --ignore-not-found=true
kubectl delete role dev-team-role --ignore-not-found=true

# Wait for pods to be terminated
print_status "Waiting for pods to be terminated..."
kubectl wait --for=delete pod -l app=nginx-demo --timeout=60s 2>/dev/null || true

print_status "✅ All resources deleted successfully!"
print_status "Cleanup completed!"
#!/bin/bash

# Simple Status Script for AKS
# This script shows the status of the nginx demo app

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[STATUS]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header "Checking nginx demo app status..."

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

echo
print_header "=== POD STATUS ==="
kubectl get pods -l app=nginx-demo

echo
print_header "=== SERVICE STATUS ==="
kubectl get svc nginx-demo-lb

echo
print_header "=== DEPLOYMENT STATUS ==="
kubectl get deployment nginx-demo

echo
print_header "=== RBAC STATUS ==="
kubectl get role,rolebinding | grep dev-team

echo
print_header "=== APPLICATION URL ==="
EXTERNAL_IP=$(kubectl get svc nginx-demo-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$EXTERNAL_IP" ]; then
    print_status "🌐 Application URL: http://$EXTERNAL_IP"
else
    print_error "External IP not yet assigned"
fi

echo
print_header "=== RECENT EVENTS ==="
kubectl get events --sort-by='.lastTimestamp' | tail -5

print_status "Status check completed!"
#!/bin/bash

# Test Ingress Access Script
# This script tests the Ingress Controller and application access

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[INGRESS TEST]${NC} $1"
}

print_header "Testing Ingress Controller and Application Access"

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

# Get Ingress Controller external IP
print_status "Getting Ingress Controller external IP..."
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
    print_error "External IP not assigned to Ingress Controller"
    print_error "Please wait a few minutes and try again"
    exit 1
fi

print_status "Ingress Controller External IP: $EXTERNAL_IP"

# Test Ingress Controller health
print_status "Testing Ingress Controller health..."
if curl -s -o /dev/null -w "%{http_code}" "http://$EXTERNAL_IP/healthz" | grep -q "404"; then
    print_status " Ingress Controller is responding"
else
    print_warning "⚠️  Ingress Controller health check failed"
fi

# Test application access with Host header
print_status "Testing application access..."
RESPONSE=$(curl -s -H "Host: nginx-demo.local" "http://$EXTERNAL_IP/")

if echo "$RESPONSE" | grep -q "nginx"; then
    print_status " Application is accessible via Ingress"
    print_status "🌐 Application URL: http://$EXTERNAL_IP"
    print_status "📝 Add Host header: nginx-demo.local"
else
    print_warning "⚠️  Application not accessible via Ingress"
    print_warning "Check if Ingress is properly configured"
fi

# Show Ingress status
echo
print_header "Ingress Status"
kubectl get ingress

echo
print_header "Ingress Controller Status"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

print_status "Ingress testing completed!"
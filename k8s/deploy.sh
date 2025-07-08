#!/bin/bash

# Simple Deploy Script for AKS
# This script deploys a minimal nginx application

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[DEPLOY]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to mask sensitive values
mask_sensitive() {
    local value="$1"
    local masked_value=""
    local length=${#value}

    if [ $length -gt 4 ]; then
        # Show first 2 and last 2 characters, mask the rest
        masked_value="${value:0:2}***${value: -2}"
    else
        # For short values, just show asterisks
        masked_value="***"
    fi
    echo "$masked_value"
}

print_status "Starting deployment of nginx demo app..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    print_error "Please run: az aks get-credentials --resource-group <RG> --name <CLUSTER>"
    exit 1
fi

# Get and mask cluster context
CLUSTER_CONTEXT=$(kubectl config current-context)
print_status "Connected to cluster: $(mask_sensitive "$CLUSTER_CONTEXT")"

# Deploy manifests in order
print_status "Deploying RBAC..."
kubectl apply -f rbac.yaml

print_status "Deploying Service..."
kubectl apply -f service.yaml

print_status "Deploying Deployment..."
kubectl apply -f deployment.yaml

print_status "Deploying NGINX Ingress Controller..."
kubectl apply -f ingress-controller.yaml

print_status "Waiting for Ingress Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-ingress-controller -n ingress-nginx

print_status "Deploying Ingress..."
kubectl apply -f ingress.yaml

print_status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-demo

print_status "Getting service information..."
kubectl get pods
kubectl get svc nginx-demo-service

# Get Ingress Controller external IP
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$EXTERNAL_IP" ]; then
    print_status " Application deployed successfully!"
    print_status "🌐 Ingress Controller URL: http://$EXTERNAL_IP"
    print_status "🌐 Application URL: http://$EXTERNAL_IP (add Host header: nginx-demo.local)"
    echo "EXTERNAL_IP=$EXTERNAL_IP" > /tmp/external_ip.txt
else
    print_warning "External IP not yet assigned. Please check again in a few minutes:"
    print_warning "kubectl get svc ingress-nginx-controller -n ingress-nginx"
fi

print_status "Deployment completed!"
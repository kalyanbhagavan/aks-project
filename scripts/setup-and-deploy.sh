#!/bin/bash

# Setup and Deploy to Private AKS
# This script sets up Azure credentials and runs the deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[DEPLOYMENT]${NC} $1"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_status "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_status "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Check if kubelogin is installed
if ! command -v kubelogin &> /dev/null; then
    print_status "Installing kubelogin..."
    # Install unzip if not present
    if ! command -v unzip &> /dev/null; then
        print_status "Installing unzip..."
        sudo apt-get update && sudo apt-get install -y unzip
    fi
    # Download and install kubelogin
    KUBELOGIN_VERSION=$(curl -s https://api.github.com/repos/Azure/kubelogin/releases/latest | jq -r '.tag_name')
    curl -LO "https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip"
    unzip kubelogin-linux-amd64.zip
    sudo mv bin/linux_amd64/kubelogin /usr/local/bin/
    rm -rf bin kubelogin-linux-amd64.zip
fi

# Check if we have the required environment variables
if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_SUBSCRIPTION_ID" ] || [ -z "$ARM_TENANT_ID" ]; then
    print_error "Missing required Azure credentials environment variables."
    print_error "Please set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, and ARM_TENANT_ID"
    exit 1
fi

# Login to Azure using service principal credentials
print_status "Logging in to Azure using service principal..."

# Login using service principal
az login --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID"

print_status "Successfully logged in to Azure using service principal"

# Set the subscription
az account set --subscription "$ARM_SUBSCRIPTION_ID"
print_status "Set subscription to: $ARM_SUBSCRIPTION_ID"

# Verify login was successful
if ! az account show &> /dev/null; then
    print_error "Failed to login to Azure CLI. Please check your credentials."
    exit 1
fi

print_status "Azure login verified successfully!"

# Export credentials for the deployment script
export ARM_CLIENT_ID="$ARM_CLIENT_ID"
export ARM_CLIENT_SECRET="$ARM_CLIENT_SECRET"
export ARM_SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID"
export ARM_TENANT_ID="$ARM_TENANT_ID"

print_status "Azure credentials exported successfully!"

# Configuration - Use environment variables or defaults
ACR_NAME="${ACR_NAME:-aksdemoacr2025}"
RESOURCE_GROUP="${RESOURCE_GROUP:-aks-challenge-rg}"
AKS_NAME="${AKS_NAME:-aks-demo}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-aksstatedemo2025}"

print_header "Starting deployment process on jumpbox..."

# Install kubectl if not present
if ! command -v kubectl &> /dev/null; then
    print_status "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Get AKS credentials
print_status "Getting AKS credentials..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin --overwrite-existing

# Get storage account key and create secret
print_status "Creating Azure Files secret..."
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT --query '[0].value' -o tsv)

kubectl create secret generic azure-files-secret \
    --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY \
    --dry-run=client -o yaml | kubectl apply -f -

# Update deployment.yaml with correct ACR name if needed
print_status "Updating deployment with correct ACR name..."
cd ~/k8s
if [ -f "deployment.yaml" ]; then
    # Replace placeholder ACR name with actual ACR name
    sed -i "s|<ACR_NAME>|$ACR_NAME|g" deployment.yaml
fi

# Deploy all manifests from k8s folder
print_status "Deploying Kubernetes manifests from k8s/ folder..."
kubectl apply -f .

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-demo

# Get service information
print_status "Getting service information..."
kubectl get pods
kubectl get svc nginx-demo-lb

# Get external IP
EXTERNAL_IP=$(kubectl get svc nginx-demo-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$EXTERNAL_IP" ]; then
    print_status "Application is accessible at: http://$EXTERNAL_IP"
    echo "EXTERNAL_IP=$EXTERNAL_IP" > /tmp/external_ip.txt
else
    print_warning "External IP not yet assigned. Please check again in a few minutes:"
    print_warning "kubectl get svc nginx-demo-lb"
fi

print_status "Deployment completed successfully!"
print_status "Setup and deployment completed!"
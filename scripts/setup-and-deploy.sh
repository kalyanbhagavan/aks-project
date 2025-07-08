#!/bin/bash

# Simplified Setup and Deploy for Private AKS
# This script handles Azure authentication and runs the k8s deployment

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

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_status "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Check if we have the required environment variables
if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_SUBSCRIPTION_ID" ] || [ -z "$ARM_TENANT_ID" ]; then
    print_error "Missing required Azure credentials environment variables."
    print_error "Please set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, and ARM_TENANT_ID"
    exit 1
fi

# Login to Azure using service principal credentials
print_status "Logging in to Azure using service principal..."
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

# Configuration - Use environment variables or defaults
RESOURCE_GROUP="${RESOURCE_GROUP:-aks-challenge-rg}"
AKS_NAME="${AKS_NAME:-aks-demo}"

print_header "Starting deployment process..."

# Get AKS credentials
print_status "Getting AKS credentials..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin --overwrite-existing

# Deploy the application using the simplified k8s scripts
print_status "Deploying nginx demo app..."
cd ~/k8s
chmod +x *.sh
./deploy.sh

print_status "Setup and deployment completed!"
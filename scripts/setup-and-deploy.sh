#!/bin/bash

# Setup and Deploy to Private AKS
# This script sets up Azure credentials and runs the deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    print_error "sshpass is not installed. Please install it first:"
    print_error "Ubuntu/Debian: sudo apt-get install sshpass"
    print_error "macOS: brew install hudochenkov/sshpass/sshpass"
    print_error "Windows: Use WSL or install via package manager"
    exit 1
fi

# Check if Azure CLI is logged in
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Get Azure credentials
print_status "Getting Azure credentials..."

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Get service principal credentials
print_status "Getting service principal credentials..."
SP_INFO=$(az ad sp list --display-name "github-actions-terraform" --query "[0]" -o json)

if [ "$SP_INFO" == "null" ] || [ -z "$SP_INFO" ]; then
    print_error "Service principal 'github-actions-terraform' not found."
    print_error "Please create it first with:"
    print_error "az ad sp create-for-rbac --name 'github-actions-terraform' --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID --sdk-auth"
    exit 1
fi

CLIENT_ID=$(echo "$SP_INFO" | jq -r '.appId')
CLIENT_SECRET=$(az ad sp credential reset --id "$CLIENT_ID" --query password -o tsv)

# Export credentials
export ARM_CLIENT_ID="$CLIENT_ID"
export ARM_CLIENT_SECRET="$CLIENT_SECRET"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_TENANT_ID="$TENANT_ID"

print_status "Azure credentials set successfully!"

# Make the deployment script executable
chmod +x scripts/deploy-to-private-aks.sh

# Run the deployment script
print_status "Starting deployment..."
./scripts/deploy-to-private-aks.sh

print_status "Setup and deployment completed!"
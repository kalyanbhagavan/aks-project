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

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_status "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    print_error "sshpass is not installed. Please install it first:"
    print_error "Ubuntu/Debian: sudo apt-get install sshpass"
    print_error "macOS: brew install hudochenkov/sshpass/sshpass"
    print_error "Windows: Use WSL or install via package manager"
    exit 1
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

# Make the deployment script executable
chmod +x scripts/deploy-to-private-aks.sh

# Run the deployment script
print_status "Starting deployment..."
./scripts/deploy-to-private-aks.sh

print_status "Setup and deployment completed!"
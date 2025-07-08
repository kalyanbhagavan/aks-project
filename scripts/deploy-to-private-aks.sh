#!/bin/bash

# Simplified Deploy to Private AKS Cluster via Jumpbox
# This script handles deployment to a private AKS cluster using existing image

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

# Configuration - Use environment variables or defaults
JUMPBOX_IP="${JUMPBOX_IP:-172.191.240.240}"
JUMPBOX_USER="${JUMPBOX_USER:-azureuser}"
JUMPBOX_PASSWORD="${JUMPBOX_PASSWORD:-P@ssw0rd123!}"
RESOURCE_GROUP="${RESOURCE_GROUP:-aks-challenge-rg}"
AKS_NAME="${AKS_NAME:-aks-demo}"

# Check prerequisites
check_prerequisites() {
    print_header "Checking prerequisites..."

    # Check and install jq
    if ! command -v jq &> /dev/null; then
        print_status "Installing jq..."
        sudo apt-get update && sudo apt-get install -y jq
    fi

    # Check and install Azure CLI
    if ! command -v az &> /dev/null; then
        print_status "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi

    # Check SSH
    if ! command -v ssh &> /dev/null; then
        print_error "SSH is not available. Please install SSH client."
        exit 1
    fi

    # Check if k8s folder exists
    if [ ! -d "k8s" ]; then
        print_error "k8s/ folder not found. Please ensure you have Kubernetes manifests in the k8s/ directory."
        exit 1
    fi

    print_status "All prerequisites are satisfied"
}

# Deploy to AKS via jumpbox
deploy_to_aks() {
    print_header "Deploying to AKS via jumpbox..."
    print_status "Jumpbox IP: $JUMPBOX_IP"
    print_status "Jumpbox User: $JUMPBOX_USER"
    print_status "Jumpbox Password: $(mask_sensitive "$JUMPBOX_PASSWORD")"

    # Copy k8s manifests to jumpbox
    print_status "Copying k8s manifests to jumpbox..."
    sshpass -p "$JUMPBOX_PASSWORD" scp -o StrictHostKeyChecking=no -r ./k8s $JUMPBOX_USER@$JUMPBOX_IP:~/

    # Execute deployment on jumpbox
    print_status "Executing deployment on jumpbox..."
    sshpass -p "$JUMPBOX_PASSWORD" ssh -o StrictHostKeyChecking=no $JUMPBOX_USER@$JUMPBOX_IP << 'SSH_EOF'
        # Colors for output
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'

        print_status() {
            echo -e "${GREEN}[JUMPBOX]${NC} $1"
        }

        print_warning() {
            echo -e "${YELLOW}[JUMPBOX]${NC} $1"
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

        # Configuration
        RESOURCE_GROUP="aks-challenge-rg"
        AKS_NAME="aks-demo"

        print_status "Starting deployment process on jumpbox..."

        # Install dependencies if not present
        print_status "Checking and installing dependencies..."
        if ! command -v kubectl &> /dev/null; then
            print_status "Installing kubectl..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi

        if ! command -v jq &> /dev/null; then
            print_status "Installing jq..."
            sudo apt-get update && sudo apt-get install -y jq
        fi

        if ! command -v az &> /dev/null; then
            print_status "Installing Azure CLI..."
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        fi

        # Login to Azure
        print_status "Logging in to Azure..."
        print_status "Client ID: $(mask_sensitive "$ARM_CLIENT_ID")"
        print_status "Subscription ID: $(mask_sensitive "$ARM_SUBSCRIPTION_ID")"
        print_status "Tenant ID: $(mask_sensitive "$ARM_TENANT_ID")"

        az login --service-principal \
            --username "$ARM_CLIENT_ID" \
            --password "$ARM_CLIENT_SECRET" \
            --tenant "$ARM_TENANT_ID"

        az account set --subscription "$ARM_SUBSCRIPTION_ID"

        # Get AKS credentials
        print_status "Getting AKS credentials..."
        az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin --overwrite-existing

        # Deploy the application using the simplified k8s scripts
        print_status "Deploying nginx demo app..."
        cd ~/k8s
        chmod +x *.sh
        ./deploy.sh

        print_status "Deployment completed successfully!"
SSH_EOF

    print_status "Deployment completed!"
}

# Azure login function
azure_login() {
    print_header "Setting up Azure authentication..."

    # Check if we have the required environment variables
    if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_SUBSCRIPTION_ID" ] || [ -z "$ARM_TENANT_ID" ]; then
        print_error "Missing required Azure credentials environment variables."
        print_error "Please set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, and ARM_TENANT_ID"
        print_error "You can also run: az login (if using Azure CLI authentication)"
        exit 1
    fi

    # Display masked credential information
    print_status "Azure credentials found:"
    print_status "  Client ID: $(mask_sensitive "$ARM_CLIENT_ID")"
    print_status "  Client Secret: $(mask_sensitive "$ARM_CLIENT_SECRET")"
    print_status "  Subscription ID: $(mask_sensitive "$ARM_SUBSCRIPTION_ID")"
    print_status "  Tenant ID: $(mask_sensitive "$ARM_TENANT_ID")"

    # Login using service principal
    print_status "Logging in to Azure using service principal..."
    az login --service-principal \
        --username "$ARM_CLIENT_ID" \
        --password "$ARM_CLIENT_SECRET" \
        --tenant "$ARM_TENANT_ID"

    print_status "Successfully logged in to Azure using service principal"

    # Set the subscription
    az account set --subscription "$ARM_SUBSCRIPTION_ID"
    print_status "Set subscription to: $(mask_sensitive "$ARM_SUBSCRIPTION_ID")"

    # Verify login was successful
    if ! az account show &> /dev/null; then
        print_error "Failed to login to Azure CLI. Please check your credentials."
        exit 1
    fi

    print_status "Azure login verified successfully!"
}

# Main execution
main() {
    print_header "Starting deployment to private AKS cluster..."

    # Check prerequisites
    check_prerequisites

    # Azure login
    azure_login

    # Deploy to AKS
    deploy_to_aks

    print_header "Deployment process completed!"
    print_status "Your application should now be accessible via the LoadBalancer external IP"
    print_status "Check the jumpbox output above for the external IP address"
}

# Run main function
main "$@"
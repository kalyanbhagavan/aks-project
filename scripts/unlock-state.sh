#!/bin/bash

# Script to unlock remote Terraform state file
# This script breaks the lease on the Azure Storage blob containing the state file

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Terraform State Unlock Tool${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --storage-account NAME    Storage account name"
    echo "  -c, --container NAME         Container name"
    echo "  -r, --resource-group NAME    Resource group name"
    echo "  -f, --state-file NAME        State file name (default: terraform.tfstate)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s tfstate2025aks -c tfstate2025aks -r aks-state-rg"
    echo "  $0 -s tfstate72095 -c tfstate -r terraform-state-rg"
    echo ""
    echo "Note: This script will break the lease on the state file to unlock it."
}

# Default values
STORAGE_ACCOUNT=""
CONTAINER=""
RESOURCE_GROUP=""
STATE_FILE="terraform.tfstate"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--storage-account)
            STORAGE_ACCOUNT="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -f|--state-file)
            STATE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_header

# Validate required parameters
if [ -z "$STORAGE_ACCOUNT" ] || [ -z "$CONTAINER" ] || [ -z "$RESOURCE_GROUP" ]; then
    print_error "Missing required parameters"
    echo ""
    show_usage
    exit 1
fi

print_status "Storage Account: $STORAGE_ACCOUNT"
print_status "Container: $CONTAINER"
print_status "Resource Group: $RESOURCE_GROUP"
print_status "State File: $STATE_FILE"
echo ""

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

print_status "Azure CLI is available and user is logged in"

# Get storage account key
print_status "Getting storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' \
    -o tsv 2>/dev/null)

if [ -z "$STORAGE_KEY" ]; then
    print_error "Failed to get storage account key"
    exit 1
fi

print_success "Storage account key retrieved"

# Check if state file exists
print_status "Checking if state file exists..."
if ! az storage blob show \
    --container-name "$CONTAINER" \
    --name "$STATE_FILE" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" &> /dev/null; then
    print_error "State file '$STATE_FILE' not found in container '$CONTAINER'"
    exit 1
fi

print_success "State file found"

# Check lease status
print_status "Checking lease status..."
LEASE_STATUS=$(az storage blob show \
    --container-name "$CONTAINER" \
    --name "$STATE_FILE" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --query 'properties.lease.status' \
    -o tsv 2>/dev/null)

print_status "Current lease status: $LEASE_STATUS"

if [ "$LEASE_STATUS" = "locked" ]; then
    print_warning "State file is locked. Attempting to break the lease..."

    # Break the lease
    if az storage blob lease break \
        --container-name "$CONTAINER" \
        --name "$STATE_FILE" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" &> /dev/null; then
        print_success "Lease broken successfully!"
    else
        print_error "Failed to break the lease"
        exit 1
    fi
else
    print_success "State file is not locked"
fi

# Verify lease is broken
print_status "Verifying lease status..."
NEW_LEASE_STATUS=$(az storage blob show \
    --container-name "$CONTAINER" \
    --name "$STATE_FILE" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --query 'properties.lease.status' \
    -o tsv 2>/dev/null)

print_status "New lease status: $NEW_LEASE_STATUS"

if [ "$NEW_LEASE_STATUS" = "unlocked" ]; then
    print_success "✅ State file is now unlocked!"
    echo ""
    print_status "You can now run Terraform commands:"
    echo "  terraform plan"
    echo "  terraform apply"
    echo "  terraform destroy"
else
    print_warning "⚠️  Lease status is still: $NEW_LEASE_STATUS"
    print_status "You may need to wait a moment or try again"
fi

echo ""
print_status "State unlock process completed"
#!/bin/bash

# Script to set up Key Vault access policies after infrastructure deployment
# This avoids circular dependencies between Key Vault and jumpbox VM

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
    echo -e "${BLUE}  Key Vault Access Setup${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --resource-group NAME    Resource group name (default: aks-challenge-rg)"
    echo "  -k, --keyvault-prefix PREFIX Key Vault name prefix (default: aks-demo-kv)"
    echo "  -j, --jumpbox-name NAME      Jumpbox VM name (default: aks-jumpbox)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 -r my-resource-group -k my-kv -j my-jumpbox"
    echo ""
    echo "Note: This script sets up Key Vault access policies for the jumpbox VM."
}

# Default values
RESOURCE_GROUP="aks-challenge-rg"
KEYVAULT_PREFIX="aks-demo-kv"
JUMPBOX_NAME="aks-jumpbox"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -k|--keyvault-prefix)
            KEYVAULT_PREFIX="$2"
            shift 2
            ;;
        -j|--jumpbox-name)
            JUMPBOX_NAME="$2"
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

print_status "Resource Group: $RESOURCE_GROUP"
print_status "Key Vault Prefix: $KEYVAULT_PREFIX"
print_status "Jumpbox Name: $JUMPBOX_NAME"
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

# Get Key Vault name
print_status "Searching for Key Vault in resource group: $RESOURCE_GROUP"

# List Key Vaults in the resource group
KEY_VAULT_LIST=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, '$KEYVAULT_PREFIX')].name" -o tsv)

if [ -z "$KEY_VAULT_LIST" ]; then
    print_error "No Key Vault found in resource group '$RESOURCE_GROUP'"
    print_error "Make sure the infrastructure has been deployed and the resource group exists."
    exit 1
fi

# Take the first Key Vault found
KEY_VAULT_NAME=$(echo "$KEY_VAULT_LIST" | head -1)
print_status "Found Key Vault: $KEY_VAULT_NAME"

# Verify Key Vault exists
if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_error "Key Vault '$KEY_VAULT_NAME' not found or not accessible"
    exit 1
fi

print_status "Key Vault '$KEY_VAULT_NAME' is accessible"

# Get jumpbox managed identity principal ID
print_status "Getting jumpbox managed identity principal ID..."

JUMPBOX_IDENTITY_ID=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$JUMPBOX_NAME" \
    --query "identity.userAssignedIdentities.*.principalId" \
    -o tsv 2>/dev/null)

if [ -z "$JUMPBOX_IDENTITY_ID" ]; then
    print_error "Could not get jumpbox managed identity principal ID"
    print_error "Make sure the jumpbox VM exists and has a user-assigned managed identity"
    exit 1
fi

print_status "Jumpbox managed identity principal ID: $JUMPBOX_IDENTITY_ID"

# Check if access policy already exists
print_status "Checking for existing access policy..."

EXISTING_POLICY=$(az keyvault show \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.accessPolicies[?objectId=='$JUMPBOX_IDENTITY_ID']" \
    -o tsv 2>/dev/null)

if [ -n "$EXISTING_POLICY" ]; then
    print_warning "Access policy for jumpbox already exists"
    print_status "Skipping access policy creation"
else
    print_status "Creating access policy for jumpbox..."

    # Create access policy
    if az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --object-id "$JUMPBOX_IDENTITY_ID" \
        --secret-permissions "Get" "List" &> /dev/null; then
        print_success "Access policy created successfully"
    else
        print_error "Failed to create access policy"
        exit 1
    fi
fi

# Test access to Key Vault secrets
print_status "Testing access to Key Vault secrets..."

if az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "github-repo-url" \
    --query "value" \
    -o tsv &> /dev/null; then
    print_status "✅ Jumpbox can access Key Vault secrets"
else
    print_warning "⚠️  Jumpbox may not have access to Key Vault secrets"
    print_warning "This might be due to timing - the managed identity may need a moment to propagate"
fi

print_status "Key Vault access setup completed!"
print_status "Jumpbox should now be able to access secrets from Key Vault"
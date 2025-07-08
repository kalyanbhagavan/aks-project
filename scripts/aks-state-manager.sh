#!/bin/bash

# AKS Terraform State Management Script
# This script handles Azure Storage backend for Terraform state files
# Requirements: Azure CLI, jq, terraform, kubectl
set -e

# Configuration from your existing project
BACKEND_RESOURCE_GROUP="${BACKEND_RESOURCE_GROUP_NAME:-aks-state-rg}"
BACKEND_STORAGE_ACCOUNT="${BACKEND_STORAGE_ACCOUNT_NAME:-tfstateaksdemoprod}"
BACKEND_CONTAINER="${BACKEND_CONTAINER_NAME:-aks-state}"
LOCATION="${LOCATION:-eastus}"
PROJECT_NAME="aks-demo"

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
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
    echo -e "${BLUE}[AKS STATE MANAGER]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking prerequisites..."

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Some features may not work properly."
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. Cluster operations may not work."
    fi

    print_success "Prerequisites check completed"
}

# Function to setup Azure authentication
setup_azure_auth() {
    print_header "Setting up Azure authentication..."

    # Check if running in CI/CD with Service Principal
    if [ -n "$AZURE_CREDENTIALS" ]; then
        print_status "Detected CI/CD environment with Service Principal"

        # Parse AZURE_CREDENTIALS JSON
        if command -v jq &> /dev/null; then
            export ARM_CLIENT_ID=$(echo "$AZURE_CREDENTIALS" | jq -r '.clientId')
            export ARM_CLIENT_SECRET=$(echo "$AZURE_CREDENTIALS" | jq -r '.clientSecret')
            export ARM_TENANT_ID=$(echo "$AZURE_CREDENTIALS" | jq -r '.tenantId')
            export ARM_SUBSCRIPTION_ID=$(echo "$AZURE_CREDENTIALS" | jq -r '.subscriptionId')
        else
            print_error "jq is required to parse AZURE_CREDENTIALS"
            exit 1
        fi

        # Set additional ARM variables for Terraform
        export ARM_USE_CLI=false
        export ARM_SKIP_PROVIDER_REGISTRATION=false

        print_status "ARM environment variables set for Service Principal authentication"
        print_status "Tenant ID: ${ARM_TENANT_ID:0:8}***"
        print_status "Subscription ID: ${ARM_SUBSCRIPTION_ID:0:8}***"

        # Set variables for script usage
        SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID"
        TENANT_ID="$ARM_TENANT_ID"

    else
        print_status "Using Azure CLI authentication"

        # Check if Azure CLI is logged in
        if ! az account show >/dev/null 2>&1; then
            print_error "Not logged in to Azure. Please run 'az login' first."
            exit 1
        fi

        SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)
        TENANT_ID=$(az account show --query 'tenantId' -o tsv)

        print_status "Authenticated to Azure via CLI"
        print_status "Subscription ID: ${SUBSCRIPTION_ID:0:8}***"
        print_status "Tenant ID: ${TENANT_ID:0:8}***"
    fi
}

# Function to create storage account for state files
create_state_storage() {
    print_header "Setting up Azure Storage for Terraform state..."

    # Check if resource group exists
    if [ -n "$ARM_CLIENT_ID" ]; then
        # Using Service Principal - use Azure CLI with service principal login
        print_status "Using Service Principal for Azure operations"

        # Login with service principal for Azure CLI operations
        az login --service-principal \
            --username "$ARM_CLIENT_ID" \
            --password "$ARM_CLIENT_SECRET" \
            --tenant "$ARM_TENANT_ID" >/dev/null 2>&1

        az account set --subscription "$ARM_SUBSCRIPTION_ID" >/dev/null 2>&1
    fi

    # Check if resource group exists
    if ! az group show --name "$BACKEND_RESOURCE_GROUP" >/dev/null 2>&1; then
        print_status "Creating resource group: $BACKEND_RESOURCE_GROUP"
        az group create \
            --name "$BACKEND_RESOURCE_GROUP" \
            --location "$LOCATION" \
            --output table
    else
        print_status "Resource group $BACKEND_RESOURCE_GROUP already exists"
    fi

    # Check if storage account exists
    if ! az storage account show --name "$BACKEND_STORAGE_ACCOUNT" --resource-group "$BACKEND_RESOURCE_GROUP" >/dev/null 2>&1; then
        print_status "Creating storage account: $BACKEND_STORAGE_ACCOUNT"
        az storage account create \
            --resource-group "$BACKEND_RESOURCE_GROUP" \
            --name "$BACKEND_STORAGE_ACCOUNT" \
            --sku Standard_LRS \
            --encryption-services blob \
            --https-only true \
            --allow-blob-public-access false \
            --output table
    else
        print_status "Storage account $BACKEND_STORAGE_ACCOUNT already exists"
    fi

    # Create container if it doesn't exist
    print_status "Creating container: $BACKEND_CONTAINER"
    az storage container create \
        --name "$BACKEND_CONTAINER" \
        --account-name "$BACKEND_STORAGE_ACCOUNT" \
        --auth-mode login \
        --output table 2>/dev/null || true

    # Enable versioning for state file protection
    print_status "Enabling blob versioning..."
    az storage account blob-service-properties update \
        --account-name "$BACKEND_STORAGE_ACCOUNT" \
        --enable-versioning true \
        --output table >/dev/null 2>&1 || true

    print_success "State storage setup completed!"

    # Export variables for use in terraform
    export ARM_RESOURCE_GROUP_NAME="$BACKEND_RESOURCE_GROUP"
    export ARM_STORAGE_ACCOUNT_NAME="$BACKEND_STORAGE_ACCOUNT"
    export ARM_CONTAINER_NAME="$BACKEND_CONTAINER"

    # Save configuration to file
    cat > "$PROJECT_ROOT/.state-config" << EOF
BACKEND_RESOURCE_GROUP="$BACKEND_RESOURCE_GROUP"
BACKEND_STORAGE_ACCOUNT="$BACKEND_STORAGE_ACCOUNT"
BACKEND_CONTAINER="$BACKEND_CONTAINER"
SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
LOCATION="$LOCATION"
PROJECT_NAME="$PROJECT_NAME"
EOF

    print_status "Configuration saved to .state-config"
}

# Function to configure terraform backend
configure_terraform_backend() {
    local env_name="$1"
    local state_key="${PROJECT_NAME}-${env_name}.terraform.tfstate"

    print_header "Configuring Terraform backend for $env_name environment..."

    # Source configuration
    if [ -f "$PROJECT_ROOT/.state-config" ]; then
        source "$PROJECT_ROOT/.state-config"
    else
        print_error "State configuration not found. Run setup first."
        exit 1
    fi

    # Update backend configuration
    cat > "$PROJECT_ROOT/backend.tf" << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$BACKEND_RESOURCE_GROUP"
    storage_account_name = "$BACKEND_STORAGE_ACCOUNT"
    container_name       = "$BACKEND_CONTAINER"
    key                  = "$state_key"
  }
}
EOF

    print_status "Backend configuration updated for $env_name"
}

# Function to initialize terraform with state
init_terraform() {
    local env_name="$1"

    print_header "Initializing Terraform for $env_name environment..."

    # Configure backend
    configure_terraform_backend "$env_name"

    # Initialize terraform
    print_status "Running terraform init..."
    cd "$PROJECT_ROOT"
    terraform init -reconfigure
    cd - >/dev/null

    print_success "Terraform initialized successfully for $env_name"
}

# Function to import existing resources
import_existing_resources() {
    local env_name="$1"

    print_header "Importing existing resources for $env_name environment..."

    # Source configuration
    if [ -f "$PROJECT_ROOT/.state-config" ]; then
        source "$PROJECT_ROOT/.state-config"
    else
        print_warning "State configuration not found. Skipping import."
        return 0
    fi

    # Determine resource group name based on environment
    if [ "$env_name" = "prod" ]; then
        RG_NAME="aks-challenge-rg"
        STORAGE_NAME="aksstatedemo2025"
        ACR_NAME="aksdemoacr2025"
        AKS_NAME="aks-demo"
    else
        RG_NAME="aks-challenge-${env_name}-rg"
        STORAGE_NAME="aksstatedemo${env_name}2025"
        ACR_NAME="aksdemoacr${env_name}2025"
        AKS_NAME="aks-demo-${env_name}"
    fi

    # Login with service principal if in CI/CD
    if [ -n "$ARM_CLIENT_ID" ]; then
        az login --service-principal \
            --username "$ARM_CLIENT_ID" \
            --password "$ARM_CLIENT_SECRET" \
            --tenant "$ARM_TENANT_ID" >/dev/null 2>&1

        az account set --subscription "$ARM_SUBSCRIPTION_ID" >/dev/null 2>&1
    fi

    cd "$PROJECT_ROOT"

    # Import Resource Group
    print_status "Checking Resource Group: $RG_NAME"
    if az group show --name "$RG_NAME" >/dev/null 2>&1; then
        if ! terraform state show azurerm_resource_group.rg >/dev/null 2>&1; then
            print_status "Importing resource group into state..."
            terraform import azurerm_resource_group.rg "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" || true
        else
            print_status "Resource group already in state"
        fi
    fi

    # Import Virtual Network
    print_status "Checking Virtual Network: aks-vnet"
    if az network vnet show --resource-group "$RG_NAME" --name "aks-vnet" >/dev/null 2>&1; then
        if ! terraform state show module.network.azurerm_virtual_network.this >/dev/null 2>&1; then
            print_status "Importing virtual network into state..."
            terraform import module.network.azurerm_virtual_network.this "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/aks-vnet" || true
        else
            print_status "Virtual network already in state"
        fi
    fi

    # Import Storage Account
    print_status "Checking Storage Account: $STORAGE_NAME"
    if az storage account show --name "$STORAGE_NAME" --resource-group "$RG_NAME" >/dev/null 2>&1; then
        if ! terraform state show module.storage.azurerm_storage_account.this >/dev/null 2>&1; then
            print_status "Importing storage account into state..."
            terraform import module.storage.azurerm_storage_account.this "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME" || true
        else
            print_status "Storage account already in state"
        fi
    fi

    # Import Container Registry
    print_status "Checking Container Registry: $ACR_NAME"
    if az acr show --name "$ACR_NAME" --resource-group "$RG_NAME" >/dev/null 2>&1; then
        if ! terraform state show module.acr.azurerm_container_registry.this >/dev/null 2>&1; then
            print_status "Importing container registry into state..."
            terraform import module.acr.azurerm_container_registry.this "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME" || true
        else
            print_status "Container registry already in state"
        fi
    fi

    # Import AKS Cluster
    print_status "Checking AKS Cluster: $AKS_NAME"
    if az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" >/dev/null 2>&1; then
        if ! terraform state show module.aks.azurerm_kubernetes_cluster.main >/dev/null 2>&1; then
            print_status "Importing AKS cluster into state..."
            terraform import module.aks.azurerm_kubernetes_cluster.main "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ContainerService/managedClusters/$AKS_NAME" || true
        else
            print_status "AKS cluster already in state"
        fi
    fi

    # Import Key Vault (if exists)
    print_status "Checking Key Vault: aks-kv-${env_name}"
    if az keyvault show --name "aks-kv-${env_name}" --resource-group "$RG_NAME" >/dev/null 2>&1; then
        if ! terraform state show module.keyvault.azurerm_key_vault.this >/dev/null 2>&1; then
            print_status "Importing key vault into state..."
            terraform import module.keyvault.azurerm_key_vault.this "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/aks-kv-${env_name}" || true
        else
            print_status "Key vault already in state"
        fi
    fi

    # Import Jumpbox VM (if exists)
    print_status "Checking Jumpbox VM: aks-jumpbox"
    if az vm show --name "aks-jumpbox" --resource-group "$RG_NAME" >/dev/null 2>&1; then
        if ! terraform state show module.vm.azurerm_linux_virtual_machine.jumpbox >/dev/null 2>&1; then
            print_status "Importing jumpbox VM into state..."
            terraform import module.vm.azurerm_linux_virtual_machine.jumpbox "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Compute/virtualMachines/aks-jumpbox" || true
        else
            print_status "Jumpbox VM already in state"
        fi
    fi

    # Import Subnets
    SUBNETS=("aks-subnet" "appgw-subnet" "jumpbox-subnet" "private-endpoints-subnet")
    for subnet in "${SUBNETS[@]}"; do
        print_status "Checking Subnet: $subnet"
        if az network vnet subnet show --resource-group "$RG_NAME" --vnet-name "aks-vnet" --name "$subnet" >/dev/null 2>&1; then
            # Determine the correct terraform resource path based on subnet name
            case "$subnet" in
                "aks-subnet")
                    tf_resource="module.network.azurerm_subnet.aks"
                    ;;
                "appgw-subnet")
                    tf_resource="module.network.azurerm_subnet.appgw"
                    ;;
                "jumpbox-subnet")
                    tf_resource="module.network.azurerm_subnet.jumpbox"
                    ;;
                "private-endpoints-subnet")
                    tf_resource="module.network.azurerm_subnet.private_endpoints"
                    ;;
            esac

            if ! terraform state show "$tf_resource" >/dev/null 2>&1; then
                print_status "Importing subnet $subnet into state..."
                terraform import "$tf_resource" "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/$subnet" || true
            else
                print_status "Subnet $subnet already in state"
            fi
        fi
    done

    cd - >/dev/null
    print_success "Resource import completed for $env_name environment"

    # Show current state summary
    print_status "Current resources in state:"
    terraform state list 2>/dev/null | head -20 || true
}

# Function to plan terraform
plan_terraform() {
    local env_name="$1"
    local action="$2"

    print_header "Planning Terraform for $env_name environment (action: $action)..."

    cd "$PROJECT_ROOT"

    # Set environment-specific variables
    if [ "$env_name" != "prod" ]; then
        export TF_VAR_resource_group_name="aks-challenge-${env_name}-rg"
        export TF_VAR_storage_account_name="aksstatedemo${env_name}2025"
        export TF_VAR_acr_name="aksdemoacr${env_name}2025"
        export TF_VAR_aks_name="aks-demo-${env_name}"
        export TF_VAR_dns_prefix="aksdemo${env_name}"
    fi

    if [ "$action" = "destroy" ]; then
        terraform plan -destroy -out=tfplan.out
    else
        terraform plan -out=tfplan.out
    fi

    cd - >/dev/null
    print_success "Plan completed successfully"
}

# Function to apply terraform
apply_terraform() {
    local env_name="$1"

    print_header "Applying Terraform for $env_name environment..."

    cd "$PROJECT_ROOT"

    # Set environment-specific variables
    if [ "$env_name" != "prod" ]; then
        export TF_VAR_resource_group_name="aks-challenge-${env_name}-rg"
        export TF_VAR_storage_account_name="aksstatedemo${env_name}2025"
        export TF_VAR_acr_name="aksdemoacr${env_name}2025"
        export TF_VAR_aks_name="aks-demo-${env_name}"
        export TF_VAR_dns_prefix="aksdemo${env_name}"
    fi

    terraform apply tfplan.out
    cd - >/dev/null

    print_success "Apply completed successfully"
}

# Function to get AKS credentials
get_aks_credentials() {
    local env_name="$1"

    print_header "Getting AKS credentials for $env_name environment..."

    # Determine names based on environment
    if [ "$env_name" = "prod" ]; then
        RG_NAME="aks-challenge-rg"
        AKS_NAME="aks-demo"
    else
        RG_NAME="aks-challenge-${env_name}-rg"
        AKS_NAME="aks-demo-${env_name}"
    fi

    # Get AKS credentials
    az aks get-credentials \
        --resource-group "$RG_NAME" \
        --name "$AKS_NAME" \
        --overwrite-existing

    print_success "AKS credentials obtained successfully"
}

# Function to test cluster connectivity
test_cluster_connectivity() {
    local env_name="$1"

    print_header "Testing AKS cluster connectivity for $env_name environment..."

    # Get credentials first
    get_aks_credentials "$env_name"

    # Test cluster connectivity
    print_status "Testing cluster connectivity..."
    kubectl cluster-info

    print_status "Getting nodes..."
    kubectl get nodes

    print_status "Getting namespaces..."
    kubectl get namespaces

    print_success "Cluster connectivity test completed"
}

# Function to backup state
backup_state() {
    local env_name="$1"
    local backup_dir="$PROJECT_ROOT/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/tfstate_${env_name}_${timestamp}.backup"

    print_header "Backing up Terraform state for $env_name environment..."

    # Create backup directory
    mkdir -p "$backup_dir"

    # Source configuration
    if [ -f "$PROJECT_ROOT/.state-config" ]; then
        source "$PROJECT_ROOT/.state-config"
    else
        print_error "State configuration not found."
        exit 1
    fi

    # Download state file
    local state_key="${PROJECT_NAME}-${env_name}.terraform.tfstate"

    az storage blob download \
        --account-name "$BACKEND_STORAGE_ACCOUNT" \
        --container-name "$BACKEND_CONTAINER" \
        --name "$state_key" \
        --file "$backup_file" \
        --auth-mode login

    print_success "State backed up to: $backup_file"
}

# Function to restore state
restore_state() {
    local env_name="$1"
    local backup_file="$2"

    if [ -z "$backup_file" ]; then
        print_error "Backup file path required"
        exit 1
    fi

    print_header "Restoring Terraform state for $env_name environment..."

    # Source configuration
    if [ -f "$PROJECT_ROOT/.state-config" ]; then
        source "$PROJECT_ROOT/.state-config"
    else
        print_error "State configuration not found."
        exit 1
    fi

    # Upload state file
    local state_key="${PROJECT_NAME}-${env_name}.terraform.tfstate"

    az storage blob upload \
        --account-name "$BACKEND_STORAGE_ACCOUNT" \
        --container-name "$BACKEND_CONTAINER" \
        --name "$state_key" \
        --file "$backup_file" \
        --auth-mode login \
        --overwrite

    print_success "State restored from: $backup_file"
}

# Function to run security scan
run_security_scan() {
    print_header "Running security scan..."

    cd "$PROJECT_ROOT"

    # Check if tfsec is installed
    if command -v tfsec &> /dev/null; then
        print_status "Running tfsec security scan..."
        tfsec . || true
    else
        print_warning "tfsec is not installed. Skipping security scan."
    fi

    # Check if checkov is installed
    if command -v checkov &> /dev/null; then
        print_status "Running checkov security scan..."
        checkov -d . || true
    else
        print_warning "checkov is not installed. Skipping security scan."
    fi

    cd - >/dev/null
    print_success "Security scan completed"
}

# Function to run health check
run_health_check() {
    local env_name="$1"

    print_header "Running health check for $env_name environment..."

    # Check Azure authentication
    if az account show >/dev/null 2>&1; then
        print_success "Azure authentication: OK"
    else
        print_error "Azure authentication: FAILED"
        return 1
    fi

    # Check Terraform state
    cd "$PROJECT_ROOT"
    if terraform state list >/dev/null 2>&1; then
        print_success "Terraform state: OK"
        print_status "Resources in state: $(terraform state list | wc -l)"
    else
        print_warning "Terraform state: Not initialized or empty"
    fi

    # Check AKS cluster if environment is specified
    if [ -n "$env_name" ]; then
        # Determine names based on environment
        if [ "$env_name" = "prod" ]; then
            RG_NAME="aks-challenge-rg"
            AKS_NAME="aks-demo"
        else
            RG_NAME="aks-challenge-${env_name}-rg"
            AKS_NAME="aks-demo-${env_name}"
        fi

        if az aks show --resource-group "$RG_NAME" --name "$AKS_NAME" >/dev/null 2>&1; then
            print_success "AKS cluster: OK"

            # Test cluster connectivity
            if get_aks_credentials "$env_name" >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
                print_success "AKS connectivity: OK"
            else
                print_warning "AKS connectivity: FAILED"
            fi
        else
            print_warning "AKS cluster: Not found"
        fi
    fi

    cd - >/dev/null
    print_success "Health check completed"
}

# Function to handle partial deployment recovery
handle_partial_deployment() {
    local env_name="$1"
    local retry_count="${2:-3}"

    print_header "Handling partial deployment recovery for $env_name environment..."

    cd "$PROJECT_ROOT"

    # Check current state
    print_status "Checking current state..."
    local current_resources=$(terraform state list 2>/dev/null | wc -l)
    print_status "Current resources in state: $current_resources"

    # Run plan to see what needs to be created/fixed
    print_status "Running plan to identify missing resources..."
    terraform plan -detailed-exitcode -out=recovery.tfplan || {
        local exit_code=$?
        if [ $exit_code -eq 2 ]; then
            print_status "Plan shows changes needed - continuing with recovery"
        else
            print_error "Plan failed with exit code: $exit_code"
            return $exit_code
        fi
    }

    # Show plan summary
    print_status "Plan summary:"
    terraform show -no-color recovery.tfplan | grep -E "(Plan:|Error:|Warning:)" || true

    # Attempt recovery with retry logic
    local attempt=1
    while [ $attempt -le $retry_count ]; do
        print_status "Recovery attempt $attempt of $retry_count..."

        if terraform apply -auto-approve recovery.tfplan; then
            print_success "Recovery successful on attempt $attempt"
            break
        else
            print_warning "Recovery attempt $attempt failed"
            if [ $attempt -eq $retry_count ]; then
                print_error "All recovery attempts failed"
                return 1
            fi

            # Wait before retry
            local wait_time=$((attempt * 30))
            print_status "Waiting ${wait_time}s before retry..."
            sleep $wait_time

            # Re-run plan for next attempt
            terraform plan -detailed-exitcode -out=recovery.tfplan || true
        fi

        ((attempt++))
    done

    cd - >/dev/null
    print_success "Partial deployment recovery completed"
}

# Function to validate state consistency
validate_state_consistency() {
    local env_name="$1"

    print_header "Validating state consistency for $env_name environment..."

    cd "$PROJECT_ROOT"

    # Refresh state to sync with Azure
    print_status "Refreshing state from Azure..."
    terraform refresh || {
        print_warning "State refresh failed - may indicate orphaned resources"
    }

    # Check for drift
    print_status "Checking for configuration drift..."
    if terraform plan -detailed-exitcode >/dev/null 2>&1; then
        print_success "No drift detected - state is consistent"
    else
        print_warning "Configuration drift detected - manual review may be needed"
        terraform plan -no-color | head -20
    fi

    # List resources in state vs Azure
    print_status "Resources in Terraform state:"
    terraform state list | sort

    print_status "Resources in Azure (for comparison):"
    local rg_name
    if [ "$env_name" = "prod" ]; then
        rg_name="aks-challenge-rg"
    else
        rg_name="aks-challenge-${env_name}-rg"
    fi

    if az group show --name "$rg_name" >/dev/null 2>&1; then
        az resource list --resource-group "$rg_name" --query "[].{Name:name,Type:type}" --output table 2>/dev/null || true
    fi

    cd - >/dev/null
    print_success "State consistency validation completed"
}

# Function to build and push via jumpbox (fallback method)
build_via_jumpbox() {
    local env_name="$1"

    print_header "Building and pushing application via jumpbox for $env_name environment..."

    # Determine names based on environment
    if [ "$env_name" = "prod" ]; then
        RG_NAME="aks-challenge-rg"
        JUMPBOX_NAME="aks-jumpbox"
    else
        RG_NAME="aks-challenge-${env_name}-rg"
        JUMPBOX_NAME="aks-jumpbox-${env_name}"
    fi

    # Wait for VM to be ready
    print_status "Waiting for jumpbox to be ready..."
    for i in {1..30}; do
        VM_STATE=$(az vm show --resource-group "$RG_NAME" --name "$JUMPBOX_NAME" --query "powerState" -o tsv 2>/dev/null || echo "unknown")
        if [[ "$VM_STATE" == "VM running" ]]; then
            print_success "Jumpbox is running"
            break
        elif [[ $i -eq 30 ]]; then
            print_error "Jumpbox failed to start"
            exit 1
        fi
        print_status "Waiting... (attempt $i/30)"
        sleep 10
    done

    # Copy application files and build
    print_status "Copying application files to jumpbox..."
    az vm run-command invoke \
        --resource-group "$RG_NAME" \
        --name "$JUMPBOX_NAME" \
        --command-id RunShellScript \
        --scripts "mkdir -p ~/app"

    # Copy Dockerfile
    az vm run-command invoke \
        --resource-group "$RG_NAME" \
        --name "$JUMPBOX_NAME" \
        --command-id RunShellScript \
        --scripts "cat > ~/app/Dockerfile << 'EOF'
$(cat "$PROJECT_ROOT/app/Dockerfile")
EOF"

    # Copy index.html
    az vm run-command invoke \
        --resource-group "$RG_NAME" \
        --name "$JUMPBOX_NAME" \
        --command-id RunShellScript \
        --scripts "cat > ~/app/index.html << 'EOF'
$(cat "$PROJECT_ROOT/app/index.html")
EOF"

    # Build and push
    print_status "Building and pushing Docker image..."
    az vm run-command invoke \
        --resource-group "$RG_NAME" \
        --name "$JUMPBOX_NAME" \
        --command-id RunShellScript \
        --scripts "
            set -e
            echo ' Building and pushing Docker image...'

            # Login to Azure and ACR
            az login --identity
            az acr login --name \${ACR_LOGIN_SERVER}

            # Build and push
            cd ~/app
            docker build -t \${ACR_LOGIN_SERVER}/demo-app:\${IMAGE_TAG} .
            docker build -t \${ACR_LOGIN_SERVER}/demo-app:latest .

            docker push \${ACR_LOGIN_SERVER}/demo-app:\${IMAGE_TAG}
            docker push \${ACR_LOGIN_SERVER}/demo-app:latest

            echo ' Build and push completed!'
        "

    print_success "Application built and pushed via jumpbox"
}

# Function to show help
show_help() {
    echo "AKS Terraform State Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  setup                     - Setup Azure Storage for state files"
    echo "  init <environment>        - Initialize Terraform with remote state"
    echo "  import <environment>      - Import existing resources"
    echo "  plan <environment> [destroy] - Plan Terraform deployment"
    echo "  apply <environment>       - Apply Terraform changes"
    echo "  full <environment> [destroy] - Run complete workflow"
    echo "  get-credentials <environment> - Get AKS credentials"
    echo "  test-cluster <environment> - Test cluster connectivity"
    echo "  backup-state <environment> - Backup Terraform state"
    echo "  restore-state <environment> <backup-file> - Restore Terraform state"
    echo "  build-via-jumpbox <environment> - Build and push via jumpbox (fallback)"
    echo "  security-scan             - Run security scan"
    echo "  health-check [environment] - Run health check"
    echo "  recover <environment> [retry-count] - Handle partial deployment recovery"
    echo "  validate-state <environment> - Validate state consistency"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 full dev"
    echo "  $0 full dev destroy"
    echo "  $0 init prod"
    echo "  $0 test-cluster dev"
    echo "  $0 backup-state prod"
    echo "  $0 restore-state dev backup.tfstate"
    echo ""
}

# Main execution
main() {
    local command="$1"
    local env_name="$2"
    local action="$3"

    # Check prerequisites
    check_prerequisites

    case "$command" in
        "setup")
            setup_azure_auth
            create_state_storage
            ;;
        "init")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            init_terraform "$env_name"
            ;;
        "import")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            import_existing_resources "$env_name"
            ;;
        "plan")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            plan_terraform "$env_name" "$action"
            ;;
        "apply")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            apply_terraform "$env_name"
            ;;
        "full")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            create_state_storage
            init_terraform "$env_name"
            import_existing_resources "$env_name"
            plan_terraform "$env_name" "$action"
            apply_terraform "$env_name"
            ;;
        "get-credentials")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            get_aks_credentials "$env_name"
            ;;
        "test-cluster")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            test_cluster_connectivity "$env_name"
            ;;
        "backup-state")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            backup_state "$env_name"
            ;;
        "restore-state")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            restore_state "$env_name" "$action"
            ;;
        "build-via-jumpbox")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            build_via_jumpbox "$env_name"
            ;;
        "recover")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            handle_partial_deployment "$env_name" "$action"
            ;;
        "validate-state")
            if [ -z "$env_name" ]; then
                print_error "Environment name required"
                show_help
                exit 1
            fi
            setup_azure_auth
            validate_state_consistency "$env_name"
            ;;
        "security-scan")
            run_security_scan
            ;;
        "health-check")
            setup_azure_auth
            run_health_check "$env_name"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

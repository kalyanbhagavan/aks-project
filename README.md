# AKS Private Cluster with NGINX Ingress Controller

## Overview
This code challenge demonstrates a secure, production-grade Azure Kubernetes Service (AKS) private cluster deployment using Terraform, with automated CI/CD via GitHub Actions. The setup includes:

 # Application deployed in this URL: http://52.255.212.179


- **Private AKS cluster** (no public API endpoint)
- **Private ACR** - Only accessible from VNet
- **NGINX Ingress Controller** for external traffic management
- **Jumpbox VM** for secure cluster access with managed identity
- **Azure Key Vault** for secure secrets management
- **Automated CI/CD** with Docker image building and deployment
- **RBAC** for access control
- **Azure Storage** for Terraform state management
- **Security masking** for sensitive information in logs and outputs

## Directory Structure
```
aks-project/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Terraform variables
├── terraform.tfvars        # Variable values
├── outputs.tf              # Terraform outputs
├── provider.tf             # Azure provider configuration
├── modules/                # Terraform modules
│   ├── aks/               # AKS cluster module
│   ├── acr/               # Azure Container Registry module
│   ├── network/           # Virtual network module
│   ├── storage/           # Storage account module
│   ├── keyvault/          # Key Vault module
│   └── vm/                # Jumpbox VM module
├── k8s/                   # Kubernetes manifests
│   ├── deployment.yaml    # Nginx application deployment
│   ├── service.yaml       # ClusterIP service
│   ├── ingress.yaml       # Ingress resource
│   ├── ingress-controller.yaml # NGINX Ingress Controller
│   ├── rbac.yaml          # RBAC roles and bindings
│   ├── deploy.sh          # Deployment script
│   ├── destroy.sh         # Cleanup script
│   ├── status.sh          # Status check script
│   └── test-ingress.sh    # Ingress testing script
├── scripts/               # Helper scripts
│   ├── setup-and-deploy.sh    # Azure auth + deployment
│   ├── deploy-to-private-aks.sh # Local to jumpbox deployment
│   ├── mask-utils.sh      # Security masking utilities
│   ├── aks-state-manager.sh # Remote State Management setup
├── app/                   # Application source
│   ├── Dockerfile         # Docker image definition
│   └── index.html         # Sample web page
└── .github/workflows/     # GitHub Actions workflows
    ├── build-and-deploy.yml       # Complete CI/CD pipeline
    ├── terraform-deploy.yml       # Infrastructure deployment
    └── setup-terraform-backend.yml # Backend setup
```

## Prerequisites
- Azure subscription with Contributor access
- Azure CLI installed and configured
- Terraform >= 1.3
- Docker (for local testing)
- kubectl (for cluster management)
- GitHub repository with Actions enabled

## Setup Instructions

### 1. Clone the Repository
```bash
git clone git@github.com:kalyanbhagavan/aks-project.git
cd aks-project
```

### 2. Configure Azure Credentials

#### Create Service Principal
```bash
# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "github-actions-aks" \
  --role contributor \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth
```

**Save the output JSON** - you'll need it for GitHub secrets.

#### Alternative: Use Existing Service Principal
If you already have a service principal:
```bash
# Get existing service principal details
az ad sp list --display-name "your-sp-name" --query "[0].{appId:appId, objectId:id}" -o table
```

### 3. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add these secrets:

#### Required Secrets:
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CREDENTIALS` | Service principal JSON | `{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}` |
| `ACR_NAME` | Azure Container Registry name | `aksdemoacr2025` |
| `JUMPBOX_IP` | Jumpbox VM public IP | `172.191.240.240` |
| `JUMPBOX_PASSWORD` | Jumpbox admin password | `P@ssw0rd123!` |
| `RESOURCE_GROUP_NAME` | Azure resource group name | `aks-challenge-rg` |
| `AKS_CLUSTER_NAME` | AKS cluster name | `aks-demo` |

#### Optional Secrets (for Terraform backend):
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `TF_STATE_RESOURCE_GROUP` | Terraform state resource group | `aks-state-rg` |
| `TF_STATE_STORAGE_ACCOUNT` | Terraform state storage account | `tfstateaksdemo` |
| `TF_STATE_CONTAINER` | Terraform state container | `aks-state` |
| `TF_STATE_KEY` | Storage account access key | `auto-generated` |

### 4. Configure Variables

Edit `terraform.tfvars` to match your environment:
```hcl
resource_group_name   = "aks-challenge-rg"
location              = "eastus"
vnet_name             = "aks-vnet"
aks_subnet_name       = "aks-subnet"
appgw_subnet_name     = "appgw-subnet"
storage_account_name  = "aksstatedemo2025"
acr_name              = "aksdemoacr2025"
aks_name              = "aks-demo"
dns_prefix            = "aksdemo"
kubernetes_version    = "1.31.9"
admin_group_object_ids = ["00000000-0000-0000-0000-000000000000"]
jumpbox_vm_name       = "aks-jumpbox"
jumpbox_admin_username = "azureuser"
jumpbox_admin_password = "P@ssw0rd123!"
github_repo_url       = "https://github.com/your-username/your-repo"
github_runner_token   = "your-runner-token"
```

### 5. Deploy Infrastructure

#### Option A: Using GitHub Actions (Recommended)
1. **Setup Terraform Backend**:
   - Go to Actions → "Setup Terraform Backend"
   - Run the workflow manually
   - Copy the output values to GitHub secrets

2. **Deploy Infrastructure**:
   - Go to Actions → "Terraform Deploy to Azure"
   - Run the workflow manually or push to main branch
   - Wait for infrastructure deployment to complete

3. **Setup Key Vault Access** (Post-deployment):
   ```bash
   # Run the Key Vault access setup script
   ./scripts/setup-keyvault-access.sh
   ```

#### Option B: Local Deployment
```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply

```

### 6. Build and Deploy Application

#### Option A: Automated CI/CD (Recommended)
1. **Push changes** to main/develop branch
2. **Workflow triggers automatically**:
   - Builds Docker image from `app/` folder
   - Pushes to ACR
   - Deploys to AKS via jumpbox
3. **Check workflow logs** for deployment status

#### Option B: Manual Deployment
```bash
# Build and push Docker image
docker build -t aksdemoacr2025.azurecr.io/nginx-demo:latest ./app
az acr login --name aksdemoacr2025
docker push aksdemoacr2025.azurecr.io/nginx-demo:latest

# Deploy via jumpbox
ssh azureuser@<jumpbox-ip>
cd ~/scripts
./setup-and-deploy.sh
```

### 7. Access the Application

#### Get Application URL:
```bash
# From jumpbox
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Or check the workflow output for the external IP
```

#### Access via Ingress:
- **URL**: `http://<EXTERNAL-IP>`
- **Host Header**: `nginx-demo.local`
- **Example**: `curl -H "Host: nginx-demo.local" http://<EXTERNAL-IP>`

## GitHub Actions Workflows

### Available Workflows:

1. **Build Image Push to ACR and Deploy to AKS**
   - **Trigger**: Push to main/develop, changes to app/ or k8s/
   - **Purpose**: Complete CI/CD pipeline

2. **Infrastructure Setup in Azure**
   - **Trigger**: Push to main/develop, changes to Terraform files
   - **Purpose**: Deploy/update infrastructure

3. **Setup Terraform Backend**
   - **Trigger**: Manual workflow dispatch
   - **Purpose**: Initialize remote state storage

#### Script-Level Masking
All deployment scripts include built-in masking functions:

```bash
# Source the masking utilities
source ./scripts/mask-utils.sh
```

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock Errors
```bash
# Force unlock state (use with caution)
terraform force-unlock <lock-id>

# For remote state locks, use Azure CLI to break the lease
az storage blob lease break \
  --container-name <container> \
  --name terraform.tfstate \
  --account-name <storage-account> \
  --account-key <storage-key>
```

#### 2. Key Vault Access Issues
```bash
# Check if jumpbox has access to Key Vault
az keyvault show --name <keyvault-name> --resource-group <rg-name>

# Verify managed identity
az vm show --resource-group <rg> --name <vm-name> --query "identity"

# Setup access policies manually
./scripts/setup-keyvault-access.sh
```

#### 3. AKS Connection Issues
```bash
# Get credentials
az aks get-credentials --resource-group <RG> --name <CLUSTER> --admin

# Verify connection
kubectl cluster-info
```

#### 4. ACR Login Issues
```bash
# Enable public access temporarily
az acr update --name <ACR_NAME> --public-network-enabled true

# Login
az acr login --name <ACR_NAME>
```

#### 5. Jumpbox Connection Issues
```bash
# Test SSH connection
ssh azureuser@<JUMPBOX_IP>

# Check if jumpbox is running
az vm show --resource-group <RG> --name <VM_NAME> --show-details
```

### Debugging Workflows

#### Enable Debug Logging
Add this to your workflow:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```
### Log Analysis
```bash
# Check application logs
kubectl logs -f deployment/nginx-demo

# Check ingress controller logs
kubectl logs -f deployment/nginx-ingress-controller -n ingress-nginx

# Check jumpbox deployment logs
ssh azureuser@<JUMPBOX_IP> "tail -f /var/log/cloud-init-output.log"

# Check Key Vault access
az keyvault secret list --vault-name <keyvault-name>
```

## Security Features

### Network Security
- **Private Subnets**: All components deployed in private subnets
- **Network Security Groups**: Controlled access to resources
- **Private Endpoints**: ACR and Key Vault use private endpoints

### Identity & Access
- **Managed Identities**: Jumpbox and AKS use managed identities
- **Service Principal**: GitHub Actions uses service principal
- **RBAC**: Kubernetes role-based access control

### Secrets Management
- **Azure Key Vault**: Centralized secrets management
- **Access Policies**: Fine-grained access control
- **Secret Rotation**: Support for secret rotation

## Cleanup

### Destroy Infrastructure
```bash
# Option A: GitHub Actions
# Go to Actions → "Infrastructure Setup" → Run workflow → Select "destroy"

# Option B: Local
terraform destroy

# Option C: Via jumpbox
cd ~/k8s
./destroy.sh
```

### Cleanup Key Vault
```bash
# Remove Key Vault access policies
az keyvault delete-policy \
  --name <keyvault-name> \
  --resource-group <rg-name> \
  --object-id <jumpbox-identity-id>
```

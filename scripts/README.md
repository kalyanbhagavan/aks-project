# Optimized Deployment Scripts

This folder contains optimized scripts for deploying to your private AKS cluster.

## Scripts Overview

### `setup-and-deploy.sh` (Optimized - 85 lines)
**Purpose**: Azure authentication + deployment on jumpbox
**What it does**:
- Installs dependencies (jq, Azure CLI, kubectl)
- Logs into Azure using service principal
- Gets AKS credentials
- Runs the simplified `k8s/deploy.sh` script

**When to use**: When you're already on the jumpbox and want to deploy

### `deploy-to-private-aks.sh` (Optimized - 150 lines)
**Purpose**: Complete deployment from local machine via jumpbox
**What it does**:
- Checks prerequisites on local machine
- Logs into Azure
- Copies k8s folder to jumpbox
- Executes deployment on jumpbox
- Uses existing Docker image (no building)

**When to use**: When deploying from your local machine or CI/CD

## Key Optimizations Made

### Removed Complexity:
- ❌ Docker image building (uses existing `aksdemoacr2025.azurecr.io/nginx-demo:latest`)
- ❌ Azure Files setup (not needed for simplified app)
- ❌ kubelogin installation (not required)
- ❌ Complex secret management
- ❌ Static asset handling

### Simplified Flow:
1. **Azure Authentication** → Service principal login
2. **AKS Credentials** → Get cluster access
3. **Deploy** → Run `k8s/deploy.sh` (simple kubectl apply)

## Usage Examples

### From Jumpbox:
```bash
# Set Azure credentials
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Run deployment
./setup-and-deploy.sh
```

### From Local Machine:
```bash
# Set all environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export JUMPBOX_IP="your-jumpbox-ip"
export JUMPBOX_PASSWORD="your-jumpbox-password"

# Run deployment
./deploy-to-private-aks.sh
```

## Benefits of Optimization

1. **Faster Execution**: Removed unnecessary steps
2. **Easier Maintenance**: Less code to maintain
3. **Better Reliability**: Fewer points of failure
4. **Clearer Purpose**: Each script has a single responsibility
5. **Reuses Existing**: Leverages the simplified k8s scripts

## Dependencies

Both scripts require:
- Azure service principal credentials
- Jumpbox access (for deploy-to-private-aks.sh)
- k8s/ folder with simplified manifests
- Existing Docker image in ACR

The scripts will automatically install missing tools (jq, Azure CLI, kubectl) on the target system.
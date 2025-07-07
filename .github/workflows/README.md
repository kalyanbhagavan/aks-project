# GitHub Actions Workflows for Azure Terraform Deployment

This directory contains GitHub Actions workflows for deploying Azure resources using Terraform with proper state management and reusable components.

## Workflows Overview

### 1. `terraform-deploy.yml`
Main workflow for Terraform deployments with manual triggers and PR integration.

**Features:**
- Automatic plan on PRs
- Apply on main branch pushes
- Manual workflow dispatch with action selection
- PR comments with plan output
- Artifact uploads for plan files

### 2. `reusable-terraform.yml`
Reusable workflow that can be called by other workflows.

**Features:**
- Configurable Terraform actions (plan/apply/destroy)
- Environment-specific deployments
- Customizable working directory
- Auto-approve options

### 3. `deploy-using-reusable.yml`
Example workflow demonstrating how to use the reusable workflow.

**Features:**
- Separate jobs for plan (PRs) and apply (main branch)
- Manual workflow dispatch support

### 4. `setup-terraform-backend.yml`
Workflow to set up the Terraform backend infrastructure.

**Features:**
- Creates resource group, storage account, and container
- Enables versioning and soft delete
- Outputs configuration for GitHub secrets

### 5. `environment-deployments.yml`
Environment-specific deployment workflow.

**Features:**
- Branch-based deployments (develop → dev, staging → staging, main → prod)
- Manual environment selection
- Reusable workflow integration

## Required GitHub Secrets

### Azure Credentials
```bash
AZURE_CREDENTIALS
```
JSON service principal credentials with the following format:
```json
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

### Terraform State Backend
```bash
TF_STATE_STORAGE_ACCOUNT    # Storage account name for Terraform state
TF_STATE_CONTAINER          # Container name for Terraform state
TF_STATE_KEY                # Storage account key for Terraform state
```

## Setup Instructions

### 1. Create Azure Service Principal

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "github-actions-terraform" \
  --role contributor \
  --scopes /subscriptions/your-subscription-id \
  --sdk-auth
```

### 2. Set Up Terraform Backend

1. Go to your GitHub repository
2. Navigate to Actions → Setup Terraform Backend
3. Click "Run workflow"
4. Fill in the required parameters:
   - Resource group name: `aks-state-rg`
   - Location: `eastus`
   - Storage account name: `akstfstate`
   - Container name: `tfstate`
5. Run the workflow
6. Copy the output values to GitHub secrets

### 3. Configure GitHub Secrets

1. Go to your repository Settings → Secrets and variables → Actions
2. Add the following secrets:

**Azure Credentials:**
- `AZURE_CREDENTIALS`: The JSON output from the service principal creation

**Terraform State:**
- `TF_STATE_STORAGE_ACCOUNT`: From the backend setup workflow
- `TF_STATE_CONTAINER`: From the backend setup workflow
- `TF_STATE_KEY`: From the backend setup workflow

### 4. Configure Environments (Optional)

For environment-specific deployments, create environments in GitHub:

1. Go to Settings → Environments
2. Create environments: `development`, `staging`, `production`
3. Configure protection rules as needed
4. Add environment-specific secrets if required

## Usage

### Automatic Deployments

- **Pull Requests**: Automatically runs `terraform plan` and comments on PR
- **Main Branch**: Automatically runs `terraform apply` on push
- **Feature Branches**: Runs `terraform plan` only

### Manual Deployments

1. Go to Actions → Terraform Deploy to Azure
2. Click "Run workflow"
3. Select the action (plan/apply/destroy)
4. Select the environment
5. Click "Run workflow"

### Environment-Specific Deployments

- Push to `develop` branch → Deploys to development environment
- Push to `staging` branch → Deploys to staging environment
- Push to `main` branch → Deploys to production environment

## Workflow Features

### State Management
- Uses Azure Storage for Terraform state
- Enables versioning and soft delete for state files
- Separate state files per environment

### Security
- Uses Azure service principal authentication
- Secrets stored in GitHub secrets
- Environment protection rules support

### Reusability
- Modular workflow design
- Reusable components for different deployment scenarios
- Consistent Terraform operations across environments

### Monitoring
- Plan outputs in PR comments
- Artifact uploads for plan files
- Workflow status tracking

## Customization

### Environment Variables
You can customize the workflows by modifying environment variables:

```yaml
env:
  TF_VERSION: "1.7.0"  # Change Terraform version
```

### Working Directory
For monorepo setups, specify the working directory:

```yaml
with:
  working-directory: ./infrastructure
```

### Auto-approve Settings
Control automatic approvals:

```yaml
with:
  auto-approve: false  # Require manual approval
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify `AZURE_CREDENTIALS` secret format
   - Check service principal permissions

2. **State Backend Errors**
   - Verify storage account and container exist
   - Check storage account key in secrets

3. **Terraform Plan Failures**
   - Check Terraform configuration syntax
   - Verify variable values in `terraform.tfvars`

### Debugging

1. Check workflow logs in GitHub Actions
2. Download plan artifacts for detailed analysis
3. Run Terraform commands locally for testing

## Best Practices

1. **Always run plan before apply**
2. **Use separate state files for different environments**
3. **Enable state locking and versioning**
4. **Review plan outputs before applying**
5. **Use environment protection rules for production**
6. **Keep Terraform version consistent across environments**
7. **Document infrastructure changes in PR descriptions**
# AKS Private Cluster Deployment with Terraform

## Overview
This project provisions a secure, production-grade Azure Kubernetes Service (AKS) private cluster using Terraform, with supporting resources:
- Private AKS cluster (no public API endpoint)
- Private Azure Container Registry (ACR)
- Azure Storage for static assets
- Jumpbox VM for secure access
- Public LoadBalancer for workload exposure
- Automated CI/CD with GitHub Actions

## Directory Structure
```
aks-project/
  main.tf, variables.tf, terraform.tfvars
  modules/           # Terraform modules (aks, acr, storage, vm, etc.)
  k8s/               # Kubernetes manifests (deployment, service, rbac, etc.)
  scripts/           # Helper scripts
  .github/workflows/ # GitHub Actions workflows
```

## Prerequisites
- Azure subscription
- Azure CLI
- Terraform >= 1.3
- Docker (for building/pushing images)
- kubectl

## Setup Instructions

### 1. Clone the Repository
```sh
git clone <your-repo-url>
cd aks-project
```

### 2. Configure Azure Credentials
- Create a Service Principal:
  ```sh
  az ad sp create-for-rbac --name "github-actions-terraform" \
    --role contributor \
    --scopes /subscriptions/<your-subscription-id> \
    --sdk-auth
  ```
- Add the output JSON as `AZURE_CREDENTIALS` in GitHub Secrets.

### 3. Set Up Terraform Backend
- Run the GitHub Actions workflow: **Setup Terraform Backend**
- Copy the output values to GitHub Secrets:
  - `TF_STATE_STORAGE_ACCOUNT`
  - `TF_STATE_CONTAINER`
  - `TF_STATE_KEY`

### 4. Configure Variables
- Edit `terraform.tfvars` as needed for your environment.

### 5. Deploy Infrastructure
- Run the GitHub Actions workflow: **Terraform Deploy to Azure**
- Or, run locally:
  ```sh
  terraform init
  terraform plan
  terraform apply
  ```

### 6. Build and Push Application Image to ACR
- Log in to ACR:
  ```sh
  az acr login --name <acr_name>
  ```
- Build and push image:
  ```sh
  docker build -t <acr_name>.azurecr.io/nginx-demo:latest .
  docker push <acr_name>.azurecr.io/nginx-demo:latest
  ```

### 7. Connect to Jumpbox
- Get the public IP of the jumpbox VM (output from Terraform or Azure Portal).
- SSH into the jumpbox:
  ```sh
  ssh azureuser@<jumpbox_public_ip>
  ```
- Ensure `kubectl` is installed (cloud-init does this by default).
- Get AKS credentials:
  ```sh
  az aks get-credentials --resource-group <resource_group> --name <aks_name> --admin
  ```

### 8. Deploy Kubernetes Manifests
- On the jumpbox, go to the `k8s/` directory (copy files if needed).
- Create the Azure Files secret:
  ```sh
  kubectl create secret generic azure-files-secret \
    --from-literal=azurestorageaccountname=<storage_account_name> \
    --from-literal=azurestorageaccountkey=<storage_account_key>
  ```
- Deploy all manifests:
  ```sh
  ./deploy-from-jumpbox.sh <acr_name>
  ```

### 9. Access the Application
- Get the external IP of the LoadBalancer service:
  ```sh
  kubectl get svc nginx-demo-lb
  ```
- Open the EXTERNAL-IP in your browser.

## RBAC for Dev Team
- The `k8s/rbac.yaml` file creates a Role and RoleBinding for a group named `dev-team`.
- Update the group name as needed for your Azure AD integration.

## Static Assets
- Static files are served from Azure Storage via Azure Files and mounted in the NGINX pod.
- Update the `azure-files-secret.yaml` with your storage account credentials (base64-encoded).

## Assumptions & Limitations
- **AKS is private**: Only accessible from the jumpbox or within the VNet.
- **GitHub Actions cannot deploy workloads directly to AKS**: Use the jumpbox for `kubectl` operations.
- **ACR is private**: Only accessible from within the VNet/AKS.
- **Public LoadBalancer**: Exposes only the sample app, not the AKS API.
- **RBAC**: Example is for a group; adapt as needed for your org.
- **Static assets**: Demo uses Azure Files; production may use CDN or other methods.

## Bonus: Best Practices
- All resources are modularized.
- State is managed securely in Azure Storage.
- Workflows are reusable and environment-aware.
- RBAC and resource limits are set for workloads.

## Troubleshooting
- Check workflow logs in GitHub Actions for errors.
- Use the jumpbox for all cluster management tasks.
- Ensure all secrets and variables are set correctly.

---

**This project demonstrates a secure, automated, and production-ready AKS deployment on Azure using Terraform and GitHub Actions.**
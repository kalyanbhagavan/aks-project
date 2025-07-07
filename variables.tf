variable "resource_group_name" {
  description = "Resource group name for all resources."
  type        = string
  default     = "aks-challenge-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "vnet_name" {
  description = "Virtual network name."
  type        = string
  default     = "aks-vnet"
}

variable "aks_subnet_name" {
  description = "AKS subnet name."
  type        = string
  default     = "aks-subnet"
}

variable "appgw_subnet_name" {
  description = "App Gateway subnet name."
  type        = string
  default     = "appgw-subnet"
}

variable "storage_account_name" {
  description = "Storage account name for remote state and static assets."
  type        = string
  default     = "aksstatedemo2024"
}

variable "acr_name" {
  description = "Azure Container Registry name."
  type        = string
  default     = "aksdemoacr2024"
}

variable "aks_name" {
  description = "AKS cluster name."
  type        = string
  default     = "aks-demo"
}

variable "dns_prefix" {
  description = "DNS prefix for AKS."
  type        = string
  default     = "aksdemo"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version."
  type        = string
  default     = "1.31.9"
}

variable "admin_group_object_ids" {
  description = "List of Azure AD group object IDs for AKS admin access."
  type        = list(string)
  default     = []
}

variable "jumpbox_vm_name" {
  description = "Name of the jumpbox virtual machine"
  type        = string
  default     = "aks-jumpbox"
}

variable "jumpbox_admin_username" {
  description = "Admin username for the jumpbox VM"
  type        = string
  default     = "azureuser"
}

variable "jumpbox_admin_password" {
  description = "Admin password for the jumpbox VM"
  type        = string
  sensitive   = true
  default     = "P@ssw0rd123!"
}

variable "github_repo_url" {
  description = "GitHub repository URL for the self-hosted runner"
  type        = string
  default     = "https://github.com/kalyanbhagavan/red-global"
}

variable "github_runner_token" {
  description = "GitHub runner registration token (set this manually or via CI/CD)"
  type        = string
  sensitive   = true
  default     = "placeholder-token"
}

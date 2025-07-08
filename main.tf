# Create resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

module "network" {
  source = "./modules/network"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = var.vnet_name
  aks_subnet_name     = var.aks_subnet_name
  appgw_subnet_name   = var.appgw_subnet_name
}

module "storage" {
  source = "./modules/storage"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  storage_account_name = var.storage_account_name
}

module "acr" {
  source = "./modules/acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = var.acr_name
  sku                 = "Premium"
}

module "aks" {
  source = "./modules/aks"

  aks_name               = var.aks_name
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  dns_prefix             = var.dns_prefix
  kubernetes_version     = var.kubernetes_version
  node_count             = 2
  vm_size                = "Standard_D2s_v3"
  aks_subnet_id          = module.network.aks_subnet_id
  admin_group_object_ids = var.admin_group_object_ids
  acr_id                 = module.acr.acr_id
}

module "jumpbox" {
  source = "./modules/vm"

  vm_name             = var.jumpbox_vm_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.jumpbox_subnet_id
  admin_username      = var.jumpbox_admin_username
  admin_password      = var.jumpbox_admin_password

  depends_on = [module.network]
}

module "keyvault" {
  source = "./modules/keyvault"

  key_vault_name      = "aks-demo-kv-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  github_repo_url     = var.github_repo_url
  github_runner_token = var.github_runner_token

  depends_on = [module.jumpbox]
}

# Generate a random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Grant jumpbox managed identity access to AKS
resource "azurerm_role_assignment" "jumpbox_aks_admin" {
  scope                = module.aks.aks_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = module.jumpbox.managed_identity_principal_id
}

# Grant jumpbox managed identity access to ACR
resource "azurerm_role_assignment" "jumpbox_acr_push" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPush"
  principal_id         = module.jumpbox.managed_identity_principal_id
}

data "azurerm_client_config" "current" {}

// TEMPORARY: Commented out to avoid duplicate access policy error. Import and re-enable for production.
/*
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = module.keyvault.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "Set",
    "List",
    "Delete"
  ]
}
*/

# Note: Key Vault secret creation removed due to access permissions
# The storage account key can be retrieved directly from the storage module output if needed
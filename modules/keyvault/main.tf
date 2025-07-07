resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Network access rules
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Grant the service principal access to the Key Vault
resource "azurerm_key_vault_access_policy" "service_principal" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge"
  ]
}

# Grant the jumpbox managed identity access to the Key Vault
resource "azurerm_key_vault_access_policy" "jumpbox" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.jumpbox_identity_principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Store GitHub repository URL (can be set manually or via Terraform)
resource "azurerm_key_vault_secret" "github_repo_url" {
  name         = "github-repo-url"
  value        = var.github_repo_url
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.service_principal]
}

# Placeholder for GitHub runner token (must be set manually)
resource "azurerm_key_vault_secret" "github_runner_token" {
  name         = "github-runner-token"
  value        = var.github_runner_token
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.service_principal]

  lifecycle {
    ignore_changes = [value]
  }
}

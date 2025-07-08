output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "static_website_url" {
  description = "Static website endpoint URL."
  value       = azurerm_storage_account.this.primary_web_endpoint
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account."
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

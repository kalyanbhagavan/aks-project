output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "static_website_url" {
  description = "Static website endpoint URL."
  value       = azurerm_storage_account.this.primary_web_endpoint
}

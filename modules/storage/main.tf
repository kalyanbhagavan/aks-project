resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version          = "TLS1_2"
  https_traffic_only_enabled = true

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

resource "azurerm_storage_container" "static" {
  name                  = "staticweb"
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

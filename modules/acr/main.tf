resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  public_network_access_enabled = false
  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

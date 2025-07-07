resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  address_space       = ["10.110.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

resource "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.110.1.0/24"]
}

resource "azurerm_subnet" "appgw" {
  name                 = var.appgw_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.110.2.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.110.3.0/24"]
}

resource "azurerm_subnet" "jumpbox" {
  name                 = "jumpbox-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.110.4.0/24"]
}

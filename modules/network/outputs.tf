output "aks_subnet_id" {
  description = "AKS subnet resource ID."
  value       = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  description = "App Gateway subnet resource ID."
  value       = azurerm_subnet.appgw.id
}

output "pe_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "jumpbox_subnet_id" {
  description = "ID of the jumpbox subnet"
  value       = azurerm_subnet.jumpbox.id
}

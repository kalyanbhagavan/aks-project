output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.jumpbox.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.jumpbox.name
}

output "public_ip" {
  description = "Public IP address of the jumpbox"
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "private_ip" {
  description = "Private IP address of the jumpbox"
  value       = azurerm_network_interface.jumpbox.private_ip_address
}

output "ssh_connection_string" {
  description = "SSH connection string for the jumpbox"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.jumpbox.ip_address}"
}

output "managed_identity_id" {
  description = "ID of the managed identity"
  value       = azurerm_user_assigned_identity.jumpbox.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the managed identity"
  value       = azurerm_user_assigned_identity.jumpbox.principal_id
}

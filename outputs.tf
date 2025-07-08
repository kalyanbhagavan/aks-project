output "jumpbox_public_ip" {
  description = "Public IP address of the jumpbox VM"
  value       = module.jumpbox.public_ip
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "load_balancer_ip" {
  description = "External IP of the LoadBalancer service (after K8s deployment)"
  value       = "To be obtained after Kubernetes deployment"
}
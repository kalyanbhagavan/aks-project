variable "vnet_name" {
  description = "Virtual network name."
  type        = string
}

variable "aks_subnet_name" {
  description = "AKS subnet name."
  type        = string
}

variable "appgw_subnet_name" {
  description = "App Gateway subnet name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

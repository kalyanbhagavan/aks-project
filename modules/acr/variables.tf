variable "acr_name" {
  description = "ACR name."
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

variable "sku" {
  description = "ACR SKU (e.g., Premium)."
  type        = string
  default     = "Premium"
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

# Note: jumpbox_identity_principal_id variable removed to avoid circular dependency

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/kalyanbhagavan/red-global"
}

variable "github_runner_token" {
  description = "GitHub runner registration token"
  type        = string
  sensitive   = true
  default     = "placeholder-token"
}

variable "subscription_id" {
  description = "Corp runner landing zone subscription ID."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "container_app_subnet_id" {
  description = "Existing delegated subnet for the internal Container App Environment."
  type        = string
}

variable "container_registry_private_endpoint_subnet_id" {
  description = "Existing private endpoint subnet for ACR."
  type        = string
}

variable "container_registry_dns_zone_id" {
  description = "Optional existing privatelink.azurecr.io private DNS zone ID."
  type        = string
  default     = null
}

variable "github_organization" {
  description = "GitHub organization for runner registration."
  type        = string
  default     = "alz-avm-tf-demo"
}

variable "github_repository" {
  description = "GitHub repository for repository-scoped runners."
  type        = string
  default     = "alz-aca-runners"
}

variable "github_personal_access_token" {
  description = "GitHub token with self-hosted runner registration permissions."
  type        = string
  sensitive   = true
}

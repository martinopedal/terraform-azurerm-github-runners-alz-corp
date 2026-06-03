variable "container_app_subnet_id" {
  type        = string
  description = "Existing delegated subnet for the internal Container App Environment."
}

variable "container_registry_private_endpoint_subnet_id" {
  type        = string
  description = "Existing private endpoint subnet for ACR."
}

variable "github_personal_access_token" {
  type        = string
  description = "GitHub token with self-hosted runner registration permissions."
  sensitive   = true
}

variable "subscription_id" {
  type        = string
  description = "Corp runner landing zone subscription ID."
}

variable "container_registry_dns_zone_id" {
  type        = string
  default     = null
  description = "Optional existing privatelink.azurecr.io private DNS zone ID."
}

variable "github_organization" {
  type        = string
  default     = "alz-avm-tf-demo"
  description = "GitHub organization for runner registration."
}

variable "github_repository" {
  type        = string
  default     = "alz-aca-runners"
  description = "GitHub repository for repository-scoped runners."
}

variable "location" {
  type        = string
  default     = "swedencentral"
  description = "Azure region."
}

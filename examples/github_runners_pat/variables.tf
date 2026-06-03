variable "container_app_subnet_id" {
  type        = string
  description = "The resource ID of the Container App subnet from ALZ Vending."
}

variable "container_registry_private_endpoint_subnet_id" {
  type        = string
  description = "The resource ID of the ACR private endpoint subnet from ALZ Vending."
}

variable "github_organization" {
  type        = string
  description = "The GitHub organization name."
}

variable "github_personal_access_token" {
  type        = string
  description = "GitHub PAT with repo and admin:org scopes."
  sensitive   = true
}

variable "github_repository" {
  type        = string
  description = "The GitHub repository name."
}

variable "container_registry_dns_zone_id" {
  type        = string
  default     = null
  description = "The private DNS zone ID for ACR. Null if handled by Azure Policy."
}

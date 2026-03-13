variable "container_app_subnet_id" {
  type        = string
  description = "The resource ID of the Container App subnet from ALZ Vending."
}

variable "container_registry_private_endpoint_subnet_id" {
  type        = string
  description = "The resource ID of the ACR private endpoint subnet from ALZ Vending."
}

variable "container_registry_dns_zone_id" {
  type        = string
  default     = null
  description = "The private DNS zone ID for ACR. Null if handled by Azure Policy."
}

variable "azuredevops_organization_url" {
  type        = string
  description = "The Azure DevOps organization URL (e.g. https://dev.azure.com/my-org)."
}

variable "azuredevops_pool_name" {
  type        = string
  description = "The Azure DevOps agent pool name."
}

variable "azuredevops_personal_access_token" {
  type        = string
  sensitive   = true
  description = "Azure DevOps PAT with Agent Pools (Read & manage) scope."
}

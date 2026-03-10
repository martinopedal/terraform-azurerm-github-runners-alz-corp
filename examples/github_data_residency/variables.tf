variable "github_url" {
  type        = string
  description = "The base URL for GitHub Enterprise Cloud with data residency (e.g., 'mycompany.ghe.com')."
}

variable "github_organization_name" {
  type        = string
  description = "The GitHub organization name."
}

variable "github_repository_name" {
  type        = string
  description = "The GitHub repository name."
}

variable "github_authentication_method" {
  type        = string
  default     = "github_app"
  description = "Authentication method: 'pat' or 'github_app'."
}

variable "github_personal_access_token" {
  type        = string
  default     = null
  description = "The personal access token for GitHub. Required when authentication_method is 'pat'."
  sensitive   = true
}

variable "github_app_id" {
  type        = string
  default     = ""
  description = "The GitHub App ID. Required when authentication_method is 'github_app'."
}

variable "github_app_installation_id" {
  type        = string
  default     = ""
  description = "The GitHub App installation ID. Required when authentication_method is 'github_app'."
}

variable "github_app_private_key" {
  type        = string
  default     = null
  description = "The GitHub App private key in PEM format. Required when authentication_method is 'github_app'."
  sensitive   = true
}

variable "location" {
  type        = string
  description = "The Azure region for deployment."
}

variable "postfix" {
  type        = string
  description = "A postfix used for naming resources."
}

variable "resource_group_name" {
  type        = string
  description = "The name of an existing resource group to deploy into."
}

variable "virtual_network_id" {
  type        = string
  description = "The resource ID of an existing VNet."
}

variable "container_app_subnet_id" {
  type        = string
  description = "The resource ID of the subnet for the Container App environment. Must be delegated to Microsoft.App/environments with a minimum /27 prefix."
}

variable "container_registry_private_endpoint_subnet_id" {
  type        = string
  description = "The resource ID of the subnet for the Container Registry private endpoint. Minimum /29 prefix."
}

variable "container_registry_dns_zone_id" {
  type        = string
  description = "The resource ID of the private DNS zone for privatelink.azurecr.io, linked to the VNet."
}

variable "subscription_id" {
  description = "Corp runner landing zone subscription ID."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Platform connectivity subscription ID that hosts the hub virtual network and Azure Firewall."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "runner_resource_group_name" {
  description = "Resource group for corp runner resources."
  type        = string
  default     = "rg-aca-runners-example"
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

variable "hub_vnet_id" {
  description = "Connectivity hub virtual network resource ID used by the consumer to wire AVNM and UDR dependencies."
  type        = string
}

variable "azure_firewall_private_ip" {
  description = "Azure Firewall private IP used as the next hop for runner egress UDRs."
  type        = string
}

variable "github_organization" {
  description = "GitHub organization for runner registration."
  type        = string
  default     = "my-org"
}

variable "github_repository" {
  description = "GitHub repository for repository-scoped runners."
  type        = string
  default     = "my-repo"
}

variable "github_personal_access_token" {
  description = "GitHub PAT or fine-grained token with self-hosted runner registration permissions."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to module resources."
  type        = map(string)
  default = {
    workload   = "corp-aca-runners"
    managed-by = "terraform"
    alz-layer  = "landing-zone-runner"
  }
}

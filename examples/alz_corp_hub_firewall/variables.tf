variable "azure_firewall_private_ip" {
  type        = string
  description = "Azure Firewall private IP used as the next hop for runner egress UDRs."
}

variable "connectivity_subscription_id" {
  type        = string
  description = "Platform connectivity subscription ID that hosts the hub virtual network and Azure Firewall."
}

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
  description = "GitHub PAT or fine-grained token with self-hosted runner registration permissions."
  sensitive   = true
}

variable "hub_vnet_id" {
  type        = string
  description = "Connectivity hub virtual network resource ID used by the consumer to wire AVNM and UDR dependencies."
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

variable "runner_resource_group_name" {
  type        = string
  default     = "rg-corp-aca-runners-swedencentral-001"
  description = "Resource group for corp runner resources."
}

variable "tags" {
  type = map(string)
  default = {
    workload   = "corp-aca-runners"
    managed-by = "terraform"
    alz-layer  = "landing-zone-runner"
  }
  description = "Tags applied to module resources."
}

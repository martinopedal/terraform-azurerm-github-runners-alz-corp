variable "container_app_subnet_id" {
  type        = string
  description = "Resource ID of the Container App subnet from ALZ Vending."
}

variable "container_registry_private_endpoint_subnet_id" {
  type        = string
  description = "Resource ID of the ACR private endpoint subnet from ALZ Vending."
}

variable "container_registry_dns_zone_id" {
  type        = string
  default     = null
  description = "Private DNS zone ID for ACR. Null if handled by Azure Policy."
}

variable "webhook_storage_private_endpoint_subnet_id" {
  type        = string
  default     = null
  description = "Subnet for the webhook Storage Queue private endpoint. Falls back to the ACR PE subnet if null."
}

variable "webhook_storage_queue_dns_zone_id" {
  type        = string
  default     = null
  description = "Private DNS zone ID for privatelink.queue.core.windows.net. Null if handled by Azure Policy."
}

variable "webhook_receiver_principal_ids" {
  type        = set(string)
  default     = []
  description = "Principal IDs of the webhook receiver(s) (e.g. Function App managed identity) granted Storage Queue Data Message Sender on the queue."
}

variable "github_organization" {
  type        = string
  description = "GitHub organization name."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository name."
}

variable "github_personal_access_token" {
  type        = string
  sensitive   = true
  description = "GitHub PAT with repo and admin:org scopes."
}

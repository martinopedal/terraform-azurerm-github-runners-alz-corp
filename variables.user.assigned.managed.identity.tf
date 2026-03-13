variable "user_assigned_managed_identity_client_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The client ID of an existing user assigned managed identity.
Only required if `user_assigned_managed_identity_creation_enabled` is `false`.

For Azure DevOps with UAMI authentication, this identity must also be configured
as a service principal in your Azure DevOps organization.
DESCRIPTION

  validation {
    condition = (
      !var.user_assigned_managed_identity_creation_enabled
      && var.version_control_system_type == "azuredevops"
      && var.version_control_system_authentication_method == "uami"
      ? var.user_assigned_managed_identity_client_id != null
      : true
    )
    error_message = "user_assigned_managed_identity_client_id must be defined when using an existing identity with UAMI authentication for Azure DevOps."
  }
}

variable "user_assigned_managed_identity_creation_enabled" {
  type        = bool
  default     = true
  description = "Whether or not to create a user assigned managed identity."
  nullable    = false
}

variable "user_assigned_managed_identity_id" {
  type        = string
  default     = null
  description = "The resource ID of an existing user assigned managed identity. Only required if `user_assigned_managed_identity_creation_enabled` is `false`."
}

variable "user_assigned_managed_identity_name" {
  type        = string
  default     = null
  description = "The name of the user assigned managed identity. If null, defaults to `uami-<postfix>`."
}

variable "user_assigned_managed_identity_principal_id" {
  type        = string
  default     = null
  description = "The principal ID of an existing user assigned managed identity. Only required if `user_assigned_managed_identity_creation_enabled` is `false`."
}

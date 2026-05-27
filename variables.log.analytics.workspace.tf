variable "log_analytics_workspace_creation_enabled" {
  type        = bool
  default     = true
  description = "Whether or not to create a log analytics workspace."
  nullable    = false
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "The resource Id of the Log Analytics Workspace. Required when `log_analytics_workspace_creation_enabled = false` and the Container App Environment is being created by this module."

  validation {
    condition     = var.log_analytics_workspace_creation_enabled || var.log_analytics_workspace_id != null
    error_message = "`log_analytics_workspace_id` must be set when `log_analytics_workspace_creation_enabled = false`. The Container App Environment requires a Log Analytics workspace, otherwise the apply fails with a 400 `LogAnalyticsConfiguration is invalid` from Azure instead of a clear plan-time error."
  }
}

variable "log_analytics_workspace_name" {
  type        = string
  default     = null
  description = "The name of the log analytics workspace. Only required if `log_analytics_workspace_creation_enabled == false`."
}

variable "log_analytics_workspace_internet_ingestion_enabled" {
  type        = bool
  default     = null
  description = "Whether or not to enable internet ingestion for the Log Analytics workspace. If null, the module defaults this to `false`."
}

variable "log_analytics_workspace_internet_query_enabled" {
  type        = bool
  default     = null
  description = "Whether or not to enable internet query for the Log Analytics workspace. If null, the module defaults this to `false`."
}

variable "log_analytics_workspace_retention_in_days" {
  type        = number
  default     = 30
  description = "The retention period for the Log Analytics Workspace."
}

variable "log_analytics_workspace_sku" {
  type        = string
  default     = "PerGB2018"
  description = "The SKU of the Log Analytics Workspace."
}

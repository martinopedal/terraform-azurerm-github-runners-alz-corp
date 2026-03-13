variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
  nullable    = false
}

variable "postfix" {
  type        = string
  description = "A postfix used to build default names if no name has been supplied for a specific resource type."

  validation {
    condition     = length(var.postfix) <= 20
    error_message = "Variable 'postfix' must be less than 20 characters due to container app job naming restrictions. '${var.postfix}' is ${length(var.postfix)} characters."
  }
}

variable "container_app_subnet_id" {
  type        = string
  description = "The resource ID of the subnet for the Container App Environment. Must have delegation for `Microsoft.App/environments`. Provided by ALZ Vending Module."
  nullable    = false
}

variable "container_registry_private_endpoint_subnet_id" {
  type        = string
  description = "The resource ID of the subnet for the Container Registry private endpoint. Provided by ALZ Vending Module."
  nullable    = false
}

variable "container_registry_dns_zone_id" {
  type        = string
  default     = null
  description = "The ID of the private DNS zone for the container registry (`privatelink.azurecr.io`). If null, DNS resolution is assumed to be handled by Azure Policy or central DNS infrastructure."
}

variable "delays" {
  type = object({
    delay_after_container_image_build              = optional(number, 60)
    delay_after_container_app_environment_creation = optional(number, 120)
  })
  default     = {}
  description = "Delays (in seconds) to apply to the module operations."
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `"CanNotDelete"` and `"ReadOnly"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "resource_group_creation_enabled" {
  type        = bool
  default     = true
  description = "Whether or not to create a resource group. Set to `false` if the resource group is provided by ALZ Vending Module."
}

variable "resource_group_name" {
  type        = string
  default     = null
  description = "The resource group where the resources will be deployed. Must be specified if `resource_group_creation_enabled == false`."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "use_zone_redundancy" {
  type        = bool
  default     = true
  description = "Enable zone redundancy for the deployment."

  validation {
    condition = !(var.use_zone_redundancy == true && contains([
      "australiacentral", "australiacentral2", "canadaeast", "koreasouth",
      "northcentralus", "southindia", "westindia", "westus", "westcentralus",
      "ukwest", "brazilsoutheast", "uaecentral", "germanynorth", "norwaywest",
      "jioindiawest", "jioindiacentral", "switzerlandwest", "francesouth",
      "southafricawest"
    ], var.location))
    error_message = "Zone redundancy is not supported in the specified location."
  }
}


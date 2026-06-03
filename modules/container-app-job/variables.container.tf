variable "container_cpu" {
  type        = number
  description = "Required CPU in cores, e.g. 0.5"
}

variable "container_image_name" {
  type        = string
  description = "Fully qualified name of the Docker image the agents should run."
  nullable    = false
}

variable "container_memory" {
  type        = string
  description = "Required memory, e.g. '250Mb'"
}

variable "custom_container_image" {
  type        = string
  default     = null
  description = "Fully qualified custom runner container image to run in the ACA Job. When set, this value is used as-is instead of registry_login_server/container_image_name."
}

variable "custom_container_image_registry_credential" {
  type = object({
    server              = string
    username            = string
    password_secret_ref = string
  })
  default     = null
  description = "Optional registry credential for custom_container_image. password_secret_ref must match an existing Container Apps secret name on the job."
}

variable "container_registry_creation_enabled" {
  type        = bool
  default     = true
  description = "Whether or not to create a container registry."
}

variable "container_registry_name" {
  type        = string
  default     = null
  description = "The name of the container registry. If null, defaults to `acr<postfix>`."
}

variable "custom_container_registry_id" {
  type        = string
  default     = null
  description = "The ID of an existing container registry. Only used if `container_registry_creation_enabled` is `false`."
}

variable "custom_container_registry_images" {
  type = map(object({
    task_name            = string
    dockerfile_path      = string
    context_path         = string
    context_access_token = optional(string, "a")
    image_names          = list(string)
  }))
  default     = null
  description = <<DESCRIPTION
Custom images to build in the container registry. Only relevant if `container_registry_creation_enabled` is `true` and `use_default_container_image` is `false`.

- `task_name` - Name of the ACR build task
- `dockerfile_path` - Path to the Dockerfile (e.g. `dockerfile`)
- `context_path` - Context in format `<repository-url>#<commit>:<folder-path>`
- `context_access_token` - Access token for the context repository
- `image_names` - List of image names to build (e.g. `["image-name:tag"]`)
DESCRIPTION
}

variable "custom_container_registry_login_server" {
  type        = string
  default     = null
  description = "The login server of an existing container registry. Required if `container_registry_creation_enabled` is `false`."
}

variable "custom_container_registry_password" {
  type        = string
  default     = null
  description = "The password for an existing container registry."
  sensitive   = true
}

variable "custom_container_registry_username" {
  type        = string
  default     = null
  description = "The username for an existing container registry."
}

variable "default_image_name" {
  type        = string
  default     = null
  description = "The default image name. If null, auto-detected from `version_control_system_type`."
}

variable "default_image_registry_dockerfile_path" {
  type        = string
  default     = "dockerfile"
  description = "The Dockerfile path for the default image build."
}

variable "default_image_repository_commit" {
  type        = string
  default     = "221742d"
  description = "The commit SHA of the default image repository."
}

variable "default_image_repository_folder_paths" {
  type = map(string)
  default = {
    azuredevops-container-app = "azure-devops-agent-aca"
    github-container-app      = "github-runner-aca"
  }
  description = "Map of image type to folder path in the default image repository."
}

variable "default_image_repository_url" {
  type        = string
  default     = "https://github.com/Azure/avm-container-images-cicd-agents-and-runners"
  description = "The URL of the default image repository."
}

variable "use_default_container_image" {
  type        = bool
  default     = true
  description = "Whether to use the default container image provided by the module."
}

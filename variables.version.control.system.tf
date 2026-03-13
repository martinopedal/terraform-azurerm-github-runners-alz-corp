variable "version_control_system_type" {
  type        = string
  description = "The type of the version control system. Allowed values are `azuredevops` or `github`."
  nullable    = false

  validation {
    condition     = contains(["azuredevops", "github"], var.version_control_system_type)
    error_message = "version_control_system_type must be 'azuredevops' or 'github'."
  }
}

variable "version_control_system_organization" {
  type        = string
  description = "The organization for the version control system. For Azure DevOps: the full URL (e.g. `https://dev.azure.com/my-org`). For GitHub: the organization name."
  nullable    = false
}

variable "version_control_system_authentication_method" {
  type        = string
  default     = "pat"
  description = <<DESCRIPTION
The authentication method for the version control system.

For Azure DevOps: `pat` or `uami`
For GitHub: `pat` or `github_app`

**Important:** This controls how the *runner/agent registers and communicates with GitHub/Azure DevOps*.
This is separate from how the *Terraform deployment authenticates to Azure* (which uses a Service Principal
or Managed Identity with Workload Identity Federation via your CI/CD pipeline).
DESCRIPTION

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? contains(["pat", "uami"], var.version_control_system_authentication_method)
      : contains(["pat", "github_app"], var.version_control_system_authentication_method)
    )
    error_message = "For Azure DevOps, authentication_method must be 'pat' or 'uami'. For GitHub, authentication_method must be 'pat' or 'github_app'."
  }
}

variable "version_control_system_personal_access_token" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The personal access token for the version control system. Required when `authentication_method` is `pat`.

For **Azure DevOps**: a PAT with `Agent Pools (Read & manage)` scope.
For **GitHub**: a classic PAT with `repo` and `admin:org` scopes (or fine-grained with equivalent).

This token is used by the **runner/agent at runtime** to register with and poll for jobs from the VCS platform.
It is NOT used for Terraform authentication to Azure.
DESCRIPTION
  sensitive   = true

  validation {
    condition = (
      var.version_control_system_authentication_method == "pat"
      ? var.version_control_system_personal_access_token != "" && var.version_control_system_personal_access_token != null
      : true
    )
    error_message = "version_control_system_personal_access_token must be defined when authentication_method is 'pat'."
  }
}

variable "version_control_system_pool_name" {
  type        = string
  default     = null
  description = "The name of the agent pool. Required for Azure DevOps."
}

variable "version_control_system_repository" {
  type        = string
  default     = null
  description = "The repository name. Required for GitHub when `runner_scope` is `repo`."
}

variable "version_control_system_runner_group" {
  type        = string
  default     = null
  description = "The runner group to add the runner to. GitHub only."
}

variable "version_control_system_runner_scope" {
  type        = string
  default     = "repo"
  description = "The scope of the GitHub runner. Must be `ent`, `org`, or `repo`. Ignored for Azure DevOps."

  validation {
    condition     = contains(["ent", "org", "repo"], var.version_control_system_runner_scope)
    error_message = "version_control_system_runner_scope must be 'ent', 'org', or 'repo'."
  }
}

variable "version_control_system_agent_name_prefix" {
  type        = string
  default     = null
  description = "The prefix for agent/runner names."
}

variable "version_control_system_agent_target_queue_length" {
  type        = number
  default     = 1
  description = "The target value for the amount of pending jobs to trigger scaling."
}

variable "version_control_system_enterprise" {
  type        = string
  default     = null
  description = "The enterprise name. Required for GitHub when `runner_scope` is `ent`."
}

variable "version_control_system_placeholder_agent_name" {
  type        = string
  default     = null
  description = "The placeholder agent name."
}

variable "version_control_system_github_url" {
  type        = string
  default     = "github.com"
  description = "The base URL for GitHub. Use `github.com` for standard GitHub, or `<subdomain>.ghe.com` for GitHub Enterprise Cloud with data residency."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.version_control_system_github_url))
    error_message = "Must be a valid domain name without protocol prefix."
  }
}

variable "version_control_system_github_application_id" {
  type        = string
  default     = ""
  description = <<DESCRIPTION
The GitHub App ID. Required when `authentication_method` is `github_app`.

The GitHub App is used by the **runner at runtime** to obtain registration tokens from GitHub.
This is NOT the same as the Azure AD App Registration used for Terraform/Azure authentication.
DESCRIPTION

  validation {
    condition = (
      var.version_control_system_authentication_method == "github_app"
      ? length(var.version_control_system_github_application_id) > 0
      : true
    )
    error_message = "github_application_id must be defined when authentication_method is 'github_app'."
  }
}

variable "version_control_system_github_application_installation_id" {
  type        = string
  default     = ""
  description = "The GitHub App installation ID. Required when `authentication_method` is `github_app`."

  validation {
    condition = (
      var.version_control_system_authentication_method == "github_app"
      ? length(var.version_control_system_github_application_installation_id) > 0
      : true
    )
    error_message = "github_application_installation_id must be defined when authentication_method is 'github_app'."
  }
}

variable "version_control_system_github_application_key" {
  type        = string
  default     = null
  description = "The GitHub App private key. Required when `authentication_method` is `github_app`."
  sensitive   = true

  validation {
    condition = (
      var.version_control_system_authentication_method == "github_app"
      ? var.version_control_system_github_application_key != "" && var.version_control_system_github_application_key != null
      : true
    )
    error_message = "github_application_key must be defined when authentication_method is 'github_app'."
  }
}

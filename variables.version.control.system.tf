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

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? var.version_control_system_pool_name != null && var.version_control_system_pool_name != ""
      : true
    )
    error_message = "version_control_system_pool_name must be defined when version_control_system_type is 'azuredevops'."
  }
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

variable "version_control_system_runner_labels" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
Custom labels to register the runner with. **GitHub only.** Azure DevOps uses pool/demands, not labels.

The labels are wired into two places that must always stay in sync:

1. The runner container's `LABELS` env var, which becomes `config.sh --labels <csv>` at registration time.
2. The KEDA `github-runner` scaler's `labels` metadata, so the scaler only triggers on queued jobs that request a matching label set.

In webhook scaling mode (`webhook_scaling_enabled = true`) the KEDA scaler is `azure-queue` and ignores GitHub labels; the labels still apply to runner registration, and your webhook receiver is responsible for filtering jobs by label before enqueueing.

Set a unique label (e.g. `["self-hosted","linux","alz-corp"]`) when you operate multiple runner pools in the same org to prevent cross-pool job pickup.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for l in var.version_control_system_runner_labels :
      length(trimspace(l)) > 0 && !can(regex(",", l)) && length(l) <= 100
    ])
    error_message = "Each label must be non-empty, contain no commas, and be <=100 chars (LABELS and KEDA `labels` are comma-separated lists)."
  }

  validation {
    condition     = length(var.version_control_system_runner_labels) == length(distinct(var.version_control_system_runner_labels))
    error_message = "version_control_system_runner_labels must not contain duplicates."
  }

  validation {
    condition = (
      var.version_control_system_type == "github" && var.runner_visibility == "private"
      ? anytrue([
        for l in var.version_control_system_runner_labels :
        contains(["alz-a1", "alz-p1", "alz-corp", "private-runner"], lower(l))
      ])
      : true
    )
    error_message = "When runner_visibility = 'private', version_control_system_runner_labels MUST include one of: 'alz-a1', 'alz-p1', 'alz-corp', 'private-runner'. This prevents public-repo workflows from accidentally landing on a corp-network-attached pool. See variable docs for runner_visibility."
  }

  validation {
    condition = (
      var.version_control_system_type == "github" && var.runner_visibility == "public"
      ? anytrue([
        for l in var.version_control_system_runner_labels :
        lower(l) == "public-runner" || startswith(lower(l), "pub-") || lower(l) == "pub"
      ])
      : true
    )
    error_message = "When runner_visibility = 'public', version_control_system_runner_labels MUST include 'public-runner', 'pub', or a label starting with 'pub-'. This forces explicit opt-in for any workflow targeting the public pool and keeps public/private label sets non-overlapping."
  }

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? length(var.version_control_system_runner_labels) == 0
      : true
    )
    error_message = "version_control_system_runner_labels is GitHub-only. Azure DevOps uses pool name and demands."
  }
}

variable "version_control_system_runner_no_default_labels" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
Disable the default `self-hosted`, `linux`, `<arch>` labels the GitHub runner adds during registration. **GitHub only.**

Forwards `NO_DEFAULT_LABELS=true` to the runner container (applies `--no-default-labels` to `config.sh`) and sets `noDefaultLabels = "true"` on the KEDA `github-runner` scaler so scaling decisions also ignore default labels.

Only set this when you provide an explicit, non-empty `version_control_system_runner_labels` set - a runner with no labels at all cannot be targeted by any workflow.
DESCRIPTION
  nullable    = false

  validation {
    condition = (
      var.version_control_system_runner_no_default_labels
      ? length(var.version_control_system_runner_labels) > 0
      : true
    )
    error_message = "version_control_system_runner_no_default_labels = true requires at least one entry in version_control_system_runner_labels (otherwise the runner would have no labels and be unreachable)."
  }

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? var.version_control_system_runner_no_default_labels == false
      : true
    )
    error_message = "version_control_system_runner_no_default_labels is GitHub-only."
  }
}

variable "runner_visibility" {
  type        = string
  default     = "private"
  description = <<DESCRIPTION
The trust boundary this runner pool operates under. **GitHub only.** Hard-isolates pools
intended for private (corp-network-attached) workloads from pools intended for public
workloads (forks, external contributors).

- `private` — pool is attached to the ALZ corp VNet, can reach private endpoints (state SAs, KV).
  Labels MUST include one of: `alz-a1`, `alz-p1`, `alz-corp`, or `private-runner` so consumer
  workflows in private repos can target it explicitly and cannot accidentally land on a public pool.
- `public`  — pool is isolated, has NO ALZ corp network access, NO access to corp KV/state.
  Labels MUST include `public-runner` or a `pub-*` prefix. Use this for pools that service
  public repos / fork PRs where workflow code is untrusted.

This is enforced at plan time by validation on `version_control_system_runner_labels` below.
Mixing public and private workloads on the same pool is a network/credential exposure risk —
keep them on separate module deployments with different visibility values.
DESCRIPTION
  nullable    = false

  validation {
    condition     = contains(["private", "public"], var.runner_visibility)
    error_message = "runner_visibility must be 'private' or 'public'."
  }

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? var.runner_visibility == "private"
      : true
    )
    error_message = "runner_visibility is GitHub-only. Azure DevOps deployments must leave it at the default 'private'."
  }
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

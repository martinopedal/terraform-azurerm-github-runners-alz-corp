# Dual-auth (GitHub App + PAT fallback) + Multi-repo registration
# Authority: .squad/decisions/inbox/copilot-directive-runner-dual-auth-2026-06-09.md
#
# Background: caj-a1 (Pool A1) was deadlocked because GitHub App 3806955 lacked org-level
# "Self-hosted runners: write" permission (403 on POST /orgs/{org}/actions/runners/registration-token).
# Workaround: Repo-scope registration (App CAN mint repo-level tokens). Safety: Add PAT fallback
# to prevent single-auth-mode stranding.
#
# This set of variables adds:
# 1. Multi-repo registration (TARGET_REPOS) for repo-scope runners
# 2. Dual-auth mode (App primary, PAT fallback) to survive App issues
# 3. Auth mode selection (auto/github_app/pat)

variable "version_control_system_target_repositories" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
**GitHub-only. Repo-scope multi-repo registration.**

List of repository names the runner should monitor when `runner_scope = "repo"`. The entrypoint
iterates these repositories, finds one with a queued job matching `runner_labels`, and registers
to that repo. Fallback: If no match, registers to the first repo in the list.

Example: `["alz-prod", "alz-firewall-ops", "alz-prod-templates"]`

**Pattern: register-and-wait.** The runner polls the GitHub Actions API to find a repository with
a queued job that matches its labels, then registers there. This prevents premature registration
to a repo with no work (which would cause the ephemeral runner to idle and exit after timeout).

**Required when** `runner_scope = "repo"` and you want ONE runner pool to service multiple repos.
If omitted, falls back to single-repo mode using `version_control_system_repository`.

**Authority:** Proven pattern in personal-runners-infra (martinopedal) and alz-aca-runners.
Codified here to avoid module consumers hand-rolling registration logic in their entrypoints.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.version_control_system_target_repositories) == length(distinct(var.version_control_system_target_repositories))
    error_message = "version_control_system_target_repositories must not contain duplicates."
  }

  validation {
    condition = alltrue([
      for r in var.version_control_system_target_repositories :
      can(regex("^[a-zA-Z0-9._-]+$", r)) && length(r) > 0 && length(r) <= 100
    ])
    error_message = "Each target repository must be a valid GitHub repo name (alphanumeric, dot, dash, underscore, 1-100 chars)."
  }

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? length(var.version_control_system_target_repositories) == 0
      : true
    )
    error_message = "version_control_system_target_repositories is GitHub-only."
  }
}

variable "version_control_system_runner_auth_mode" {
  type        = string
  default     = "auto"
  description = <<DESCRIPTION
**GitHub-only. Dual-auth mode: GitHub App primary, PAT fallback.**

Controls how the runner authenticates to GitHub when registering and polling for jobs:

- `auto` (default) - Try GitHub App auth first. If App vars are missing or App token mint fails,
  fall back to PAT (requires `pat_fallback_secret_value`). Recommended for resilience.
- `github_app` - GitHub App only. Exit if App auth fails (no fallback). Use when you want strict
  App-only enforcement.
- `pat` - PAT only. Use `version_control_system_personal_access_token` directly. Legacy mode.

**Why dual-auth?** Pool A1 (caj-a1) was deadlocked when GitHub App 3806955 lacked org-level
permissions and had to switch to repo-scope. PAT fallback ensures a misconfigured App doesn't
strand the entire pool. Authority: .squad/decisions/inbox/copilot-directive-runner-dual-auth-2026-06-09.md

**Entrypoint implementation:** The runner image's entrypoint (`runner-images/linux/entrypoint.sh`)
reads `RUNNER_AUTH_MODE` and implements the try-App-then-PAT logic. This variable just passes
through to the container env var `RUNNER_AUTH_MODE`.

Ignored for Azure DevOps (which uses PAT or UAMI only).
DESCRIPTION
  nullable    = false

  validation {
    condition     = contains(["auto", "github_app", "pat"], var.version_control_system_runner_auth_mode)
    error_message = "version_control_system_runner_auth_mode must be 'auto', 'github_app', or 'pat'."
  }

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? var.version_control_system_runner_auth_mode == "auto"
      : true
    )
    error_message = "version_control_system_runner_auth_mode is GitHub-only. Leave at default 'auto' for Azure DevOps."
  }
}

variable "version_control_system_pat_fallback_secret_value" {
  type        = string
  default     = null
  description = <<DESCRIPTION
**GitHub-only. PAT fallback secret for dual-auth mode.**

Personal Access Token (ghp_* or github_pat_*) used as fallback when `runner_auth_mode = "auto"`
and GitHub App auth fails. Required scopes: `repo` + `admin:org` (classic PAT) or equivalent
fine-grained token.

**When required:**
- `runner_auth_mode = "auto"` (recommended) - PAT is fallback if App fails
- `runner_auth_mode = "pat"` - PAT is primary (no App)

**When optional:**
- `runner_auth_mode = "github_app"` - App-only, no fallback (PAT ignored)

**Security:** This is a sensitive value. Pass from Key Vault or a secure CI/CD variable. The module
will mount it as a Container Apps secret and inject it as env var `PAT_FALLBACK_ACCESS_TOKEN` in
the runner container.

**Lifecycle note:** If you switch from PAT-only (`authentication_method = "pat"`) to dual-auth
(`authentication_method = "github_app"` + `runner_auth_mode = "auto"`), set this variable to
the existing `version_control_system_personal_access_token` value so the PAT remains available
as fallback.

Ignored for Azure DevOps.
DESCRIPTION
  sensitive   = true

  validation {
    condition = (
      var.version_control_system_runner_auth_mode == "auto" || var.version_control_system_runner_auth_mode == "pat"
      ? var.version_control_system_pat_fallback_secret_value != "" && var.version_control_system_pat_fallback_secret_value != null
      : true
    )
    error_message = "version_control_system_pat_fallback_secret_value must be defined when runner_auth_mode is 'auto' or 'pat'."
  }

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? var.version_control_system_pat_fallback_secret_value == null
      : true
    )
    error_message = "version_control_system_pat_fallback_secret_value is GitHub-only."
  }
}

variable "version_control_system_disable_auto_update" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
**GitHub-only. Disable GitHub Actions runner auto-update.**

When true, sets `DISABLE_AUTO_UPDATE=true` in the runner container, which prevents the GitHub
Actions runner binary from auto-updating during job execution. Recommended for ephemeral runners
in Container Apps to avoid mid-job update disruptions.

**Why default true?** Ephemeral runners are short-lived (one job, then destroy). Auto-update is
unnecessary and adds latency. Image updates should be controlled via the container image version,
not in-place runner binary updates.

Ignored for Azure DevOps.
DESCRIPTION
  nullable    = false

  validation {
    condition = (
      var.version_control_system_type == "azuredevops"
      ? var.version_control_system_disable_auto_update == true
      : true
    )
    error_message = "version_control_system_disable_auto_update is GitHub-only. Leave at default true for Azure DevOps."
  }
}

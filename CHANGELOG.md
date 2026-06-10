# Changelog

## 1.1.0 (Unreleased)

### Features

- **Dual-auth support (GitHub App + PAT fallback):** Added `version_control_system_runner_auth_mode` variable to support three auth modes:
  - `auto` (default) - Try GitHub App first, fall back to PAT if App fails
  - `github_app` - GitHub App only (strict enforcement, no fallback)
  - `pat` - PAT only (legacy mode)
  
  Authority: `.squad/decisions/inbox/copilot-directive-runner-dual-auth-2026-06-09.md`
  
  Context: Pool A1 (caj-a1) was deadlocked when GitHub App 3806955 lacked org-level "Self-hosted runners: write" permission. PAT fallback ensures a misconfigured App doesn't strand the entire pool.

- **Multi-repo registration (repo-scope):** Added `version_control_system_target_repositories` variable to support ONE runner pool servicing MULTIPLE repos. The entrypoint iterates TARGET_REPOS, finds a repo with a queued job matching labels, and registers there. Fallback: registers to first repo if no match. This implements the **register-and-wait** pattern proven in personal-runners-infra and alz-aca-runners.

- **PAT fallback secret:** Added `version_control_system_pat_fallback_secret_value` for dual-auth mode. Required when `runner_auth_mode = "auto"` or `"pat"`, ignored when `runner_auth_mode = "github_app"`.

- **Disable auto-update:** Added `version_control_system_disable_auto_update` (default `true`) to prevent GitHub Actions runner binary from auto-updating during job execution. Recommended for ephemeral runners.

- **Dual-auth entrypoint:** Shipped `runner-images/linux/entrypoint.sh` implementing the App→PAT fallback logic, multi-repo registration, and register-and-wait pattern. Consumers can use this entrypoint in their custom images or rely on the module to inject the necessary env vars into AVM-based images.

### Breaking Changes

- `environment_variables_github` local now uses `concat()` to compose env vars from multiple sources. No user-facing variable signature changes, but internal logic refactored.

### Fixes

- Added `APP_INSTALLATION_ID` env var to App auth path (was missing in v1.0.0).
- Consolidated PAT and App auth env var logic into a single composable `environment_variables_github` local.

## 1.0.0

- Prepared the ALZ Corp ACA runner module for first stable registry release.
- Confirmed the module has the standard Terraform module files, examples, CI validation, MIT license, and generated terraform-docs README content.
- Renamed the Terraform requirements file to `versions.tf` to match the standard module layout.
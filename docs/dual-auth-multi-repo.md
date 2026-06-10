# Dual-Auth & Multi-Repo Registration

## Overview

As of v1.1.0, this module supports **dual-auth** (GitHub App primary, PAT fallback) and **multi-repo registration** (one runner pool servicing multiple repositories in repo-scope mode).

## Problem Statement

**Pool A1 (caj-a1) deadlock incident (2026-06-09):**

GitHub App 3806955 (`alz-avm-tf-demo` org) lacked org-level "Self-hosted runners: write" permission. When the runner tried to register at org-scope, it got HTTP 403 on `POST /orgs/{org}/actions/runners/registration-token`. This deadlocked the entire platform CD pipeline because the runner couldn't register and KEDA kept spawning containers that failed auth and exited.

**Root cause:** Single-auth-mode stranding. The pool was configured for App-only auth. When the App permission was misconfigured, there was no fallback, and the pool was dead until manual ARM patches restored service.

**Solution:** Dual-auth mode. Try GitHub App first (preferred for least-privilege and fine-grained permissions), but fall back to PAT if App auth fails (missing vars, token mint error, HTTP 401/403). This prevents a single auth misconfiguration from stranding the entire pool.

## Usage

### Scenario 1: Dual-auth with repo-scope multi-repo (recommended)

```hcl
module "runner_pool_a1" {
  source  = "martinopedal/terraform-azurerm-github-runners-alz-corp"
  version = "~> 1.1.0"

  # ... (other required vars: location, name, resource_group_name, etc.)

  version_control_system_type                        = "github"
  version_control_system_organization                = "alz-avm-tf-demo"
  version_control_system_authentication_method       = "github_app"
  version_control_system_runner_scope                = "repo"
  
  # Multi-repo registration (register-and-wait pattern)
  version_control_system_target_repositories         = [
    "alz-prod",
    "alz-firewall-ops",
    "alz-prod-templates",
  ]
  
  version_control_system_runner_labels               = ["self-hosted", "alz-a1", "linux", "x64"]
  
  # GitHub App (primary auth)
  version_control_system_github_application_id              = "3806955"
  version_control_system_github_application_installation_id = "139071845"
  version_control_system_github_application_key             = var.github_app_private_key  # From Key Vault
  
  # PAT fallback (safety net)
  version_control_system_runner_auth_mode            = "auto"  # Try App → PAT fallback
  version_control_system_pat_fallback_secret_value   = var.github_pat_fallback  # From Key Vault
  
  version_control_system_disable_auto_update         = true
}
```

**How it works:**

1. KEDA polls GitHub API for queued jobs matching `alz-a1` label across the 3 target repos.
2. When a job is queued, KEDA scales up a runner container.
3. The runner's entrypoint (`runner-images/linux/entrypoint.sh`) runs:
   - Try to mint GitHub App installation token.
   - If App token mint succeeds, use it to fetch a repo-level registration token.
   - If App token mint fails (missing vars, 401, 403), fall back to PAT.
   - Iterate `TARGET_REPOS`, check for queued jobs matching labels.
   - Register to the first repo with a matching queued job.
   - If no match, register to `REPOS[0]` (alz-prod) as fallback (handles pending reusable-workflow CDs).
4. Runner polls GitHub for jobs, executes one job (ephemeral), deregisters, exits.

**Register-and-wait pattern:** The entrypoint polls the GitHub Actions API to find a repository with a queued job that matches its labels BEFORE registering. This prevents premature registration to a repo with no work (which would cause the ephemeral runner to idle and exit after timeout, wasting resources).

### Scenario 2: App-only (strict enforcement, no fallback)

```hcl
version_control_system_authentication_method       = "github_app"
version_control_system_runner_auth_mode            = "github_app"  # No PAT fallback
# Omit version_control_system_pat_fallback_secret_value
```

Use this when you want **strict App-only enforcement** and prefer the runner to fail-fast if the App is misconfigured (rather than falling back to a less-privileged PAT).

### Scenario 3: PAT-only (legacy mode)

```hcl
version_control_system_authentication_method       = "pat"
version_control_system_personal_access_token       = var.github_pat
version_control_system_runner_auth_mode            = "pat"  # Or "auto" (PAT is the fallback here)
```

Use this when you don't have a GitHub App or prefer classic PAT auth. Not recommended for new deployments (App is least-privilege and auditable).

## Key Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `version_control_system_runner_auth_mode` | `string` | `"auto"` | Auth mode: `auto` (App→PAT fallback), `github_app` (App only), `pat` (PAT only). |
| `version_control_system_target_repositories` | `list(string)` | `[]` | List of repo names for repo-scope multi-repo registration. Example: `["alz-prod", "alz-firewall-ops"]`. |
| `version_control_system_pat_fallback_secret_value` | `string` (sensitive) | `null` | PAT fallback token. Required when `runner_auth_mode = "auto"` or `"pat"`. |
| `version_control_system_disable_auto_update` | `bool` | `true` | Disable GitHub Actions runner auto-update (recommended for ephemeral runners). |

## Entrypoint

The module includes `runner-images/linux/entrypoint.sh`, which implements:

1. **Dual-auth logic** (App→PAT fallback)
2. **Multi-repo registration** (register-and-wait pattern)
3. **Repo-scope and org-scope support**
4. **PKCS#8 PEM format** for GitHub App private key (PKCS#1 fails with `openssl dgst`)

Consumers can use this entrypoint in their custom images or rely on the module to inject the necessary env vars into AVM-based images.

## Env Vars Wired by Module

When you set the variables above, the module injects these env vars into the runner container:

| Env Var | Source | Purpose |
|---------|--------|---------|
| `ORG_NAME` | `version_control_system_organization` | GitHub org name |
| `RUNNER_SCOPE` | `version_control_system_runner_scope` | `"org"` or `"repo"` |
| `TARGET_REPOS` | `version_control_system_target_repositories` | Comma-separated repo names (repo-scope multi-repo) |
| `RUNNER_LABELS` | `version_control_system_runner_labels` | `"LABELS"` (not `RUNNER_LABELS` — AVM compat) |
| `RUNNER_AUTH_MODE` | `version_control_system_runner_auth_mode` | `"auto"`, `"github_app"`, or `"pat"` |
| `APP_ID` | `version_control_system_github_application_id` | GitHub App ID |
| `APP_INSTALLATION_ID` | `version_control_system_github_application_installation_id` | GitHub App installation ID |
| `APP_PRIVATE_KEY` | `version_control_system_github_application_key` | GitHub App PEM (PKCS#8) |
| `PAT_FALLBACK_ACCESS_TOKEN` | `version_control_system_pat_fallback_secret_value` | PAT fallback token |
| `DISABLE_AUTO_UPDATE` | `version_control_system_disable_auto_update` | `"true"` (if enabled) |
| `EPHEMERAL` | (hardcoded) | `"true"` (always ephemeral) |

## KEDA Scaler

**KEDA metadata for repo-scope multi-repo:**

```hcl
metadata = {
  owner                     = "alz-avm-tf-demo"
  repos                     = "alz-prod"  # KEDA polls ONLY this repo (not all TARGET_REPOS)
  runnerScope               = "repo"
  targetWorkflowQueueLength = "1"
  applicationID             = "3806955"
  installationID            = "139071845"
  labels                    = "self-hosted,alz-a1,linux,x64"
}
```

**Important:** KEDA `repos` is singular (one repo), but the runner's `TARGET_REPOS` is plural (multiple repos). KEDA scales based on queued jobs in the PRIMARY repo (`alz-prod`), but the runner can pick up jobs from ANY of the TARGET_REPOS. This is intentional: KEDA scaling is cost-optimized (poll one repo), but runner registration is flexible (service all repos).

## Authority

- `.squad/decisions/inbox/copilot-directive-runner-dual-auth-2026-06-09.md` — Martin's directive for dual-auth requirement.
- `.squad/decisions.md` ADR-BATCH5-* — ALZ network rollout decisions (context for why caj-a1 matters).
- `martinopedal/personal-runners-infra` — Proven register-and-wait pattern (Pool P1).
- `alz-avm-tf-demo/alz-aca-runners` — Org corp runner pool (Pool A2, will consume this module post-v1.1.0).

## Migration from v1.0.0 to v1.1.0

**No breaking changes** in variable signatures. Existing v1.0.0 consumers can upgrade without modification. New variables are optional (default behavior matches v1.0.0).

To **opt in** to dual-auth + multi-repo:

1. Set `version_control_system_runner_auth_mode = "auto"`
2. Add `version_control_system_target_repositories = [...]`
3. Add `version_control_system_pat_fallback_secret_value = var.pat`
4. Update your runner image to use the module's `runner-images/linux/entrypoint.sh` (or ensure your image supports `RUNNER_AUTH_MODE`, `TARGET_REPOS`, `PAT_FALLBACK_ACCESS_TOKEN` env vars).

## PKCS#8 PEM Requirement

**Critical:** GitHub App private key MUST be PKCS#8 format (`BEGIN PRIVATE KEY`), not PKCS#1 (`BEGIN RSA PRIVATE KEY`). The entrypoint uses `openssl dgst -sha256 -sign` for JWT signing, which requires PKCS#8.

Convert PKCS#1 → PKCS#8:

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
  -in github-app-pkcs1.pem \
  -out github-app-pkcs8.pem
```

Store the PKCS#8 PEM in Key Vault, reference it via `version_control_system_github_application_key = data.azurerm_key_vault_secret.github_app_key.value`.

## Troubleshooting

**Symptom:** KEDA scaling works, but runners don't register.

**Diagnosis:**

1. Check ACA Job execution logs: `az containerapp job execution logs show ...`
2. Look for `❌ Failed to mint GitHub App token` → App vars missing or PEM malformed (PKCS#1 vs PKCS#8).
3. Look for `❌ Failed to create repo-level registration token` → App lacks repo-level self-hosted-runners write permission.
4. Look for `ℹ️ No queued jobs matched labels` → Register-and-wait exited (no work). This is expected when KEDA scales up proactively but the job hasn't landed yet. KEDA will retry on the next poll.

**Symptom:** PAT fallback not triggering.

**Diagnosis:**

1. `runner_auth_mode = "github_app"` (no fallback) — change to `"auto"`.
2. `version_control_system_pat_fallback_secret_value` not set — add it.
3. Entrypoint logs show `🔐 Auth mode: github_app (no fallback)` — confirms App-only mode.

**Symptom:** Runners register but jobs land on the wrong runner pool.

**Diagnosis:**

1. Label mismatch. Check `version_control_system_runner_labels` includes a unique label like `alz-a1`.
2. KEDA `labels` metadata out of sync with container `LABELS` env var. The module keeps them in sync; if you override `container_app_environment_variables`, ensure you also update KEDA metadata.

## See Also

- [FIREWALL-RULES.md](FIREWALL-RULES.md) — Network requirements for runners (PE-only ACR, GitHub API egress).
- [WEBHOOKS.md](WEBHOOKS.md) — Webhook scaling mode (alternative to KEDA's GitHub API polling).
- [examples/](examples/) — Full working examples of dual-auth + multi-repo.

locals {
  keda_meta_data       = tomap(jsondecode(local.keda_meta_data_final))
  keda_meta_data_final = var.webhook_scaling_enabled ? jsonencode(local.keda_meta_data_webhook) : (var.version_control_system_type == "azuredevops" ? jsonencode(local.keda_meta_data_azure_devops) : jsonencode(local.keda_meta_data_github))

  # KEDA github-runner scaler `repos` poll list. When repo-scope multi-repo is configured via
  # version_control_system_target_repositories, the scaler must poll ALL of those repos so a job
  # queued in any of them triggers a scale-up. Otherwise the scaler only polls the single
  # version_control_system_repository and jobs in the other target repos sit queued forever
  # (they only run if they coincide with a job in the single polled repo). The runner entrypoint
  # already iterates TARGET_REPOS to register to the repo with the matching queued job.
  keda_github_repos = length(var.version_control_system_target_repositories) > 0 ? join(",", var.version_control_system_target_repositories) : var.version_control_system_repository

  keda_meta_data_webhook = {
    queueName   = var.webhook_queue_name
    accountName = local.webhook_storage_account_name
    queueLength = tostring(var.webhook_queue_length_per_runner)
  }

  keda_meta_data_azure_devops = {
    poolName                   = var.version_control_system_pool_name
    targetPipelinesQueueLength = var.version_control_system_agent_target_queue_length
  }

  keda_meta_data_github = merge(
    var.version_control_system_authentication_method == "pat" ? {
      owner                     = var.version_control_system_organization
      repos                     = local.keda_github_repos
      targetWorkflowQueueLength = var.version_control_system_agent_target_queue_length
      runnerScope               = var.version_control_system_runner_scope
      githubApiURL              = var.version_control_system_github_url != "github.com" ? "https://api.${var.version_control_system_github_url}" : ""
      } : {
      owner                     = var.version_control_system_organization
      repos                     = local.keda_github_repos
      targetWorkflowQueueLength = var.version_control_system_agent_target_queue_length
      runnerScope               = var.version_control_system_runner_scope
      applicationID             = var.version_control_system_github_application_id
      installationID            = var.version_control_system_github_application_installation_id
      githubApiURL              = var.version_control_system_github_url != "github.com" ? "https://api.${var.version_control_system_github_url}" : ""
    },
    length(var.version_control_system_runner_labels) > 0 ? { labels = join(",", var.version_control_system_runner_labels) } : {},
    var.version_control_system_runner_no_default_labels ? { noDefaultLabels = "true" } : {},
    var.version_control_system_keda_enable_etags ? { enableEtags = "true" } : {},
  )
}

locals {
  environment_variables       = concat(tolist(jsondecode(local.environment_variables_final)), local.environment_variables_runner_labels, tolist(var.container_app_environment_variables))
  environment_variables_final = var.version_control_system_type == "azuredevops" ? jsonencode(local.environment_variables_azure_devops) : jsonencode(local.environment_variables_github)

  environment_variables_runner_labels = var.version_control_system_type == "github" ? concat(
    length(var.version_control_system_runner_labels) > 0 ? [{ name = "LABELS", value = join(",", var.version_control_system_runner_labels) }] : [],
    var.version_control_system_runner_no_default_labels ? [{ name = "NO_DEFAULT_LABELS", value = "true" }] : [],
  ) : []

  environment_variables_azure_devops = [
    { name = "AZP_POOL", value = var.version_control_system_pool_name },
    { name = "AZP_AGENT_NAME_PREFIX", value = local.version_control_system_agent_name_prefix }
  ]

  environment_variables_github = concat(
    # Base env vars (common to all auth methods)
    [
      { name = "RUNNER_NAME_PREFIX", value = local.version_control_system_agent_name_prefix },
      { name = "REPO_URL", value = local.github_repository_url },
      { name = "RUNNER_SCOPE", value = var.version_control_system_runner_scope },
      { name = "EPHEMERAL", value = "true" },
      { name = "ORG_NAME", value = var.version_control_system_organization },
      { name = "ENTERPRISE_NAME", value = var.version_control_system_enterprise },
      { name = "RUNNER_GROUP", value = var.version_control_system_runner_group },
      { name = "GITHUB_HOST", value = var.version_control_system_github_url },
    ],
    # App-specific env vars (when authentication_method = github_app)
    var.version_control_system_authentication_method == "github_app" ? [
      { name = "APP_ID", value = var.version_control_system_github_application_id },
      { name = "APP_INSTALLATION_ID", value = var.version_control_system_github_application_installation_id },
    ] : [],
    # Dual-auth mode (RUNNER_AUTH_MODE)
    [{ name = "RUNNER_AUTH_MODE", value = var.version_control_system_runner_auth_mode }],
    # Multi-repo registration (TARGET_REPOS for repo-scope)
    length(var.version_control_system_target_repositories) > 0 ? [
      { name = "TARGET_REPOS", value = join(",", var.version_control_system_target_repositories) }
    ] : [],
    # DISABLE_AUTO_UPDATE
    var.version_control_system_disable_auto_update ? [
      { name = "DISABLE_AUTO_UPDATE", value = "true" }
    ] : [],
  )
}

locals {
  environment_variables_placeholder       = tolist(jsondecode(local.environment_variables_placeholder_final))
  environment_variables_placeholder_final = var.version_control_system_type == "azuredevops" ? jsonencode(local.environment_variables_placeholder_azure_devops) : jsonencode(local.environment_variables_placeholder_github)
  environment_variables_placeholder_azure_devops = [
    { name = "AZP_AGENT_NAME", value = local.version_control_system_placeholder_agent_name },
    { name = "AZP_PLACEHOLDER", value = "true" }
  ]
  environment_variables_placeholder_github = []
}

locals {
  sensitive_environment_variables       = concat(tolist(jsondecode(local.sensitive_environment_variables_final)), tolist(var.container_app_sensitive_environment_variables))
  sensitive_environment_variables_final = var.version_control_system_type == "azuredevops" ? jsonencode(local.sensitive_environment_variables_azure_devops) : jsonencode(local.sensitive_environment_variables_github)

  # In webhook mode, KEDA uses the azure-queue scaler with UAMI auth - no secret-based KEDA auth
  # is required. Sensitive vars are still mounted as container secrets/env vars for the runner
  # itself, but the keda_auth_name is stripped so they aren't wired into the scaler trigger.
  sensitive_environment_variables_azure_devops = var.version_control_system_authentication_method == "uami" ? [
    { name = "AZP_URL", value = var.version_control_system_organization, container_app_secret_name = "organization-url", keda_auth_name = var.webhook_scaling_enabled ? null : "organizationURL" },
    { name = "USRMI_ID", value = local.user_assigned_managed_identity_client_id, container_app_secret_name = "user-assigned-identity-client-id", keda_auth_name = null }
    ] : [
    { name = "AZP_URL", value = var.version_control_system_organization, container_app_secret_name = "organization-url", keda_auth_name = var.webhook_scaling_enabled ? null : "organizationURL" },
    { name = "AZP_TOKEN", value = var.version_control_system_personal_access_token, container_app_secret_name = "personal-access-token", keda_auth_name = var.webhook_scaling_enabled ? null : "personalAccessToken" }
  ]

  sensitive_environment_variables_github = concat(
    # Primary auth secret (PAT or App)
    var.version_control_system_authentication_method == "pat" ? [
      { name = "ACCESS_TOKEN", value = var.version_control_system_personal_access_token, container_app_secret_name = "personal-access-token", keda_auth_name = var.webhook_scaling_enabled ? null : "personalAccessToken" }
      ] : [
      { name = "APP_PRIVATE_KEY", value = var.version_control_system_github_application_key, container_app_secret_name = "application-key", keda_auth_name = var.webhook_scaling_enabled ? null : "appKey" }
    ],
    # PAT fallback (when runner_auth_mode = auto or pat)
    (var.version_control_system_runner_auth_mode == "auto" || var.version_control_system_runner_auth_mode == "pat") && var.version_control_system_pat_fallback_secret_value != null ? [
      { name = "PAT_FALLBACK_ACCESS_TOKEN", value = var.version_control_system_pat_fallback_secret_value, container_app_secret_name = "pat-fallback-token", keda_auth_name = null }
    ] : [],
  )
}

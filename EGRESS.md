# Network egress requirements

These egress FQDNs must be opened at the hub Azure Firewall for force-tunneled landing-zone spokes. This module targets corp Linux ACA runners in force-tunneled spokes, so these are prerequisites before deployment.

The list below was derived from observed runner traffic and Azure Firewall deny logs. Validate any addition against your own deny logs before allowing it.

## GitHub Actions runner control plane

| FQDN | Port/proto | Why |
|---|---:|---|
| `github.com`, `*.github.com`, `api.github.com` | 443 HTTPS | GitHub web/API, runner registration, job polling, KEDA GitHub scaler |
| `*.actions.githubusercontent.com` | 443 HTTPS | Actions runtime, OIDC, pipeline orchestration |
| `vstoken.actions.githubusercontent.com` | 443 HTTPS | Runner token refresh |
| `codeload.github.com` | 443 HTTPS | `actions/checkout` archives |
| `results-receiver.actions.githubusercontent.com` | 443 HTTPS | Actions results and annotations |
| `objects.githubusercontent.com`, `release-assets.githubusercontent.com` | 443 HTTPS | GitHub object/release downloads; Terraform provider redirects |
| `pkg-containers.githubusercontent.com`, `ghcr.io`, `*.ghcr.io` | 443 HTTPS | GHCR images and layers |
| `*.blob.core.windows.net` | 443 HTTPS | Actions cache, artifacts, logs |

## ACA platform and image pulls

| FQDN | Port/proto | Why |
|---|---:|---|
| `mcr.microsoft.com`, `*.data.mcr.microsoft.com`, `*.cdn.mscr.io` | 443 HTTPS | ACA/runner base images and MCR layers |
| `*.azurecr.io`, `*.data.azurecr.io` | 443 HTTPS | ACR login/data where the public path is used |
| `shavamanifestazurecdnprod1.azureedge.net`, `shavamanifestcdnprod1.azureedge.net` | 443 HTTPS | ACA platform manifest CDN |
| `*.<region>.azurecontainerapps.io` | 80 HTTP, 443 HTTPS | ACA regional canaries, data-plane, and platform telemetry |
| `*.ext.azurecontainerapps.dev` | 443 HTTPS | ACA extensions service; easy to miss because it is `.dev`, not `.io` |
| `*.servicebus.windows.net` | 443 HTTPS | ACA/KEDA scale trigger dependency |

## Azure control plane and observability

| FQDN | Port/proto | Why |
|---|---:|---|
| `management.azure.com`, `management.core.windows.net` | 443 HTTPS | ARM control plane and compatibility endpoint |
| `login.microsoftonline.com`, `*.login.microsoftonline.com`, `login.microsoft.com`, `*.login.microsoft.com`, `login.windows.net`, `graph.microsoft.com`, `*.identity.azure.net` | 443 HTTPS | Entra ID, Graph, managed identity |
| `*.vault.azure.net`, `*.vaultcore.azure.net` | 443 HTTPS | Key Vault secrets and fallback/control |
| `*.monitor.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`, `*.handler.control.monitor.azure.com`, `*.ingest.monitor.azure.com`, `global.handler.control.monitor.azure.com` | 443 HTTPS | Monitor/Log Analytics/AMA |
| `*.azure-automation.net`, `*.agentsvc.azure-automation.net`, `*.guestconfiguration.azure.com` | 443 HTTPS | Automation and Guest Configuration |
| `api.cloud.defender.microsoft.com` | 443 HTTPS | Defender for Cloud API |

## Package and build tools commonly used by runner jobs

| FQDN | Port/proto | Why |
|---|---:|---|
| `*.npmjs.org`, `*.npmjs.com`, `registry.npmjs.org`, `registry.yarnpkg.com` | 443 HTTPS | Node/Yarn package restore |
| `pypi.org`, `*.pypi.org`, `files.pythonhosted.org`, `releases.astral.sh` | 443 HTTPS | Python/uv package restore |
| `*.nuget.org`, `api.nuget.org` | 443 HTTPS | .NET package restore |
| `*.hashicorp.com`, `*.terraform.io`, `registry.terraform.io`, `releases.hashicorp.com`, `checkpoint-api.hashicorp.com` | 443 HTTPS | Terraform init/provider downloads/version check |
| `check.trivy.dev` | 443 HTTPS | Trivy vulnerability DB/version check |
| `azure.archive.ubuntu.com`, `archive.ubuntu.com`, `security.ubuntu.com` | 80 HTTP, 443 HTTPS | Ubuntu packages |
| `packages.microsoft.com` | 443 HTTPS | Microsoft Linux packages, az CLI, dotnet |

## Candidate FQDNs to validate before allowing

Do not allow these until validated through your own firewall deny logs: `raw.githubusercontent.com` (some examples use it for bootstrap scripts), `www.powershellgallery.com` and PowerShell Gallery CDN endpoints, runner self-update hosts such as `objects-origin.githubusercontent.com`, and `*.pkg.github.com`.

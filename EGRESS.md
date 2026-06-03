# Network egress requirements

These egress FQDNs must be opened at the hub Azure Firewall for force-tunneled spokes; see `alz-firewall-ops/FIREWALL-EGRESS-IMPLEMENTED.md` (canonical). This module targets corp Linux ACA runners in force-tunneled ALZ spokes, so these are active prerequisites before deployment.

Source of truth: `alz-avm-tf-demo/alz-firewall-ops` (`policy/fwp-hub-swedencentral/rcg-runners-alz.tf`, `rcg-platform.tf`, `rcg-baseline-app.tf`). Originally missed = discovered reactively from firewall denies / PRs #13, #16, #28, #29.

## GitHub Actions runner control plane

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `github.com`, `*.github.com`, `api.github.com` | 443 HTTPS | GitHub web/API, runner registration, job polling, KEDA GitHub scaler | No |
| `*.actions.githubusercontent.com` | 443 HTTPS | Actions runtime, OIDC, pipeline orchestration | Yes (#13/#29) |
| `vstoken.actions.githubusercontent.com` | 443 HTTPS | Runner token refresh | Yes (#13) |
| `codeload.github.com` | 443 HTTPS | `actions/checkout` archives | Yes (#13) |
| `results-receiver.actions.githubusercontent.com` | 443 HTTPS | Actions results and annotations | Yes (#13) |
| `objects.githubusercontent.com`, `release-assets.githubusercontent.com` | 443 HTTPS | GitHub object/release downloads; Terraform provider redirects | `release-assets` yes (#29) |
| `pkg-containers.githubusercontent.com`, `ghcr.io`, `*.ghcr.io` | 443 HTTPS | GHCR images and layers | `pkg-containers` yes (#13) |
| `*.blob.core.windows.net` | 443 HTTPS | Actions cache, artifacts, logs | Yes (#13) |

## ACA platform and image pulls

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `mcr.microsoft.com`, `*.data.mcr.microsoft.com`, `*.cdn.mscr.io` | 443 HTTPS | ACA/runner base images and MCR layers | No |
| `*.azurecr.io`, `*.data.azurecr.io` | 443 HTTPS | ACR login/data where public path is used | Yes (#16) |
| `shavamanifestazurecdnprod1.azureedge.net`, `shavamanifestcdnprod1.azureedge.net` | 443 HTTPS | ACA platform manifest CDN | Yes (#28) |
| `telemetry-proxy.calmsky-bbc8d292.eastus.azurecontainerapps.io` | 443 HTTPS | ACA internal telemetry endpoint observed by platform | Yes (#28) |
| `*.swedencentral.azurecontainerapps.io` | 80 HTTP, 443 HTTPS | ACA regional canaries / data-plane | Yes (#28) |
| `*.ext.azurecontainerapps.dev` | 443 HTTPS | ACA extensions service; easy to miss because it is `.dev`, not `.io` | Yes (#28/#29) |
| `*.servicebus.windows.net` | 443 HTTPS | ACA/KEDA scale trigger dependency | Yes (#29) |

## Azure control plane and observability

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `management.azure.com`, `management.core.windows.net` | 443 HTTPS | ARM control plane and compatibility endpoint | `management.core` yes (#16) |
| `login.microsoftonline.com`, `*.login.microsoftonline.com`, `login.microsoft.com`, `*.login.microsoft.com`, `login.windows.net`, `graph.microsoft.com`, `*.identity.azure.net` | 443 HTTPS | Entra ID, Graph, managed identity | Regional/fallback/MSI yes (#16) |
| `*.vault.azure.net`, `*.vaultcore.azure.net` | 443 HTTPS | Key Vault secrets and fallback/control | Yes (#16/#29) |
| `*.monitor.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`, `*.handler.control.monitor.azure.com`, `*.ingest.monitor.azure.com`, `global.handler.control.monitor.azure.com` | 443 HTTPS | Monitor/Log Analytics/AMA | Yes (#16/#29) |
| `*.azure-automation.net`, `*.agentsvc.azure-automation.net`, `*.guestconfiguration.azure.com` | 443 HTTPS | Automation and Guest Configuration | Yes (#16/#29) |
| `api.cloud.defender.microsoft.com` | 443 HTTPS | Defender for Cloud API | Yes (#29) |

## Package and build tools commonly used by runner jobs

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `*.npmjs.org`, `*.npmjs.com`, `registry.npmjs.org`, `registry.yarnpkg.com` | 443 HTTPS | Node/Yarn package restore | No |
| `pypi.org`, `*.pypi.org`, `files.pythonhosted.org`, `releases.astral.sh` | 443 HTTPS | Python/uv package restore | No |
| `*.nuget.org`, `api.nuget.org` | 443 HTTPS | .NET package restore | No |
| `*.hashicorp.com`, `*.terraform.io`, `registry.terraform.io`, `releases.hashicorp.com`, `checkpoint-api.hashicorp.com` | 443 HTTPS | Terraform init/provider downloads/version check | `checkpoint-api` yes (#28) |
| `check.trivy.dev` | 443 HTTPS | Trivy vulnerability DB/version check | Yes (#29) |
| `azure.archive.ubuntu.com`, `archive.ubuntu.com`, `security.ubuntu.com` | 80 HTTP, 443 HTTPS | Ubuntu packages | Yes (#28) |
| `packages.microsoft.com` | 443 HTTPS | Microsoft Linux packages / az CLI / dotnet | Yes (#28) |

## Candidate gaps not implemented in alz-firewall-ops

Do not treat these as allowed until validated through firewall deny logs and added to `alz-firewall-ops`: `raw.githubusercontent.com`, runner self-update hosts such as `objects-origin.githubusercontent.com`, and `*.pkg.github.com`.

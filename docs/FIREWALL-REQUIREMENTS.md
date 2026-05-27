# Firewall requirements

Implementation tracker: [`alz-firewall-ops/docs/FIREWALL-EGRESS-IMPLEMENTED.md`](https://github.com/alz-avm-tf-demo/alz-firewall-ops/blob/main/docs/FIREWALL-EGRESS-IMPLEMENTED.md).

Corp ACA runners are in an ALZ spoke behind AVNM and central Azure Firewall. Source identity is the Container App Job managed identity unless the row states ACA platform or ACR Task.

## github.com

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Runner UAMI | GitHub web/API | `github.com` | 443 | HTTPS |
| Runner UAMI/KEDA scaler | GitHub API | `api.github.com` | 443 | HTTPS |
| Runner UAMI | Actions service and OIDC | `*.actions.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Checkout archives | `codeload.github.com` | 443 | HTTPS |
| Runner UAMI | Actions results | `results-receiver.actions.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Actions pipeline orchestration | `pipelines.actions.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Raw content and release assets | `raw.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Release assets | `release-assets.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Runner updates | `objects.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Runner updates | `objects-origin.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Runner updates | `github-releases.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | Runner updates | `github-registry-files.githubusercontent.com` | 443 | HTTPS |

## ghcr.io and packages

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Runner UAMI | GitHub Container Registry | `ghcr.io` | 443 | HTTPS |
| Runner UAMI | GHCR layers | `pkg-containers.githubusercontent.com` | 443 | HTTPS |
| Runner UAMI | GitHub Packages | `*.pkg.github.com` | 443 | HTTPS |

## GHA cache, artifacts, and logs

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Runner UAMI | Actions cache/artifacts/logs | `*.blob.core.windows.net` | 443 | HTTPS |

## Azure management and identity

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Runner UAMI/ACA platform | Entra ID | `login.microsoftonline.com` | 443 | HTTPS |
| Runner UAMI/ACA platform | Regional Entra ID | `*.login.microsoftonline.com` | 443 | HTTPS |
| Runner UAMI/ACA platform | Entra ID fallback | `*.login.microsoft.com` | 443 | HTTPS |
| Runner UAMI/ACA platform | Azure Resource Manager | `management.azure.com` | 443 | HTTPS |
| Runner UAMI/ACA platform | Managed identity endpoint | `*.identity.azure.net` | 443 | HTTPS |

## Key Vault

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Runner UAMI | Key Vault secrets used by workflows | `*.vault.azure.net` | 443 | HTTPS |

## ACR and image build

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Runner UAMI/ACR Task | Azure Container Registry | `*.azurecr.io` | 443 | HTTPS |
| ACR Task | Microsoft Container Registry | `mcr.microsoft.com` | 443 | HTTPS |
| ACR Task | MCR image layers | `*.data.mcr.microsoft.com` | 443 | HTTPS |
| ACR Task | MCR CDN fallback | `*.cdn.mscr.io` | 443 | HTTPS |
| ACR Task | Microsoft package feeds | `packages.microsoft.com` | 443 | HTTPS |

## Monitoring

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| ACA platform | Log Analytics ingestion | `*.ods.opinsights.azure.com` | 443 | HTTPS |
| ACA platform | Operations management | `*.oms.opinsights.azure.com` | 443 | HTTPS |
| ACA platform | Azure Monitor ingestion | `*.ingest.monitor.azure.com` | 443 | HTTPS |
| ACA platform | Azure Monitor API | `*.monitor.azure.com` | 443 | HTTPS |

## ACA platform

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| ACA platform | ACA platform images | `mcr.microsoft.com` | 443 | HTTPS |
| ACA platform | MCR image layers | `*.data.mcr.microsoft.com` | 443 | HTTPS |
| ACA platform | AKS packages | `packages.aks.azure.com` | 443 | HTTPS |
| ACA platform | AKS mirror | `acs-mirror.azureedge.net` | 443 | HTTPS |
| ACA platform | ACA control plane | `*.azurecontainerapps.dev` | 443 | HTTPS |
| ACA platform | KEDA platform dependency | `*.servicebus.windows.net` | 443 | HTTPS |

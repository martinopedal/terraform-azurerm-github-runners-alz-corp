# Firewall Rules for Self-Hosted Runners/Agents

This document lists all FQDN and network rules required on the **Azure Firewall** (or NVA) providing
central egress in an Azure Landing Zone Corp topology.

These rules must be in place **before** deploying this module, otherwise runner registration,
image builds, and job execution will fail.

---

## Azure Container Registry (ACR) - Image Build & Pull

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `*.azurecr.io` | 443 | HTTPS | ACR login server, image pull/push |
| `*.blob.core.windows.net` | 443 | HTTPS | ACR blob storage layer (image layers) |
| `mcr.microsoft.com` | 443 | HTTPS | Microsoft Container Registry (base images) |
| `*.data.mcr.microsoft.com` | 443 | HTTPS | MCR data endpoint (CDN-backed) |
| `*.cdn.mscr.io` | 443 | HTTPS | MCR CDN fallback |
| `packages.microsoft.com` | 443 | HTTPS | Microsoft package repos (used in Dockerfiles) |

> **Note:** If using private endpoint for ACR, the `*.azurecr.io` and `*.blob.core.windows.net` rules
> are only needed for the **ACR Task** image build (which runs on ACR infrastructure, not inside your VNet).
> Image pull from the Container App Job uses the private endpoint.

---

## GitHub - Runner Registration & Job Execution

Required when `version_control_system_type = "github"`:

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `github.com` | 443 | HTTPS | GitHub API and web (runner registration) |
| `api.github.com` | 443 | HTTPS | GitHub REST API (KEDA scaler polling, runner ops) |
| `*.actions.githubusercontent.com` | 443 | HTTPS | GitHub Actions service (workflow job downloads) |
| `codeload.github.com` | 443 | HTTPS | Git archive downloads (`actions/checkout`) |
| `*.pkg.github.com` | 443 | HTTPS | GitHub Packages |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry |
| `*.actions.githubusercontent.com` | 443 | HTTPS | Actions artifacts and logs upload |
| `results-receiver.actions.githubusercontent.com` | 443 | HTTPS | Actions results service |
| `pipelines.actions.githubusercontent.com` | 443 | HTTPS | Actions pipeline orchestration |
| `objects.githubusercontent.com` | 443 | HTTPS | GitHub release asset downloads |
| `raw.githubusercontent.com` | 443 | HTTPS | Raw file content (used by ACR Task for default image build) |

### GitHub Enterprise Cloud with Data Residency

If using `version_control_system_github_url = "<subdomain>.ghe.com"`, replace the above GitHub FQDNs
with equivalent `*.ghe.com` endpoints. Refer to
[GitHub documentation on GHEC data residency networking](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-network-settings).

---

## Azure DevOps - Agent Registration & Job Execution

Required when `version_control_system_type = "azuredevops"`:

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `dev.azure.com` | 443 | HTTPS | Azure DevOps Services API |
| `*.dev.azure.com` | 443 | HTTPS | Organization-specific endpoints |
| `*.vsassets.io` | 443 | HTTPS | Azure DevOps static assets / agent download |
| `*.visualstudio.com` | 443 | HTTPS | Legacy Azure DevOps endpoints (still used by agent) |
| `vstsagentpackage.azureedge.net` | 443 | HTTPS | Agent package downloads |
| `*.vstsmms.visualstudio.com` | 443 | HTTPS | Azure DevOps telemetry |
| `login.microsoftonline.com` | 443 | HTTPS | Azure AD authentication (UAMI/SPN token acquisition) |
| `management.azure.com` | 443 | HTTPS | Azure ARM (UAMI authentication, KEDA scaler) |

> **Note on UAMI authentication:** When using `authentication_method = "uami"`, the agent uses
> Managed Identity to authenticate. The identity must be pre-configured in Azure DevOps as a
> service principal with Administrator role on the target agent pool. The `login.microsoftonline.com`
> and `management.azure.com` endpoints are required for token acquisition.

---

## Azure Platform - Always Required

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `login.microsoftonline.com` | 443 | HTTPS | Azure AD / Entra ID authentication |
| `management.azure.com` | 443 | HTTPS | Azure Resource Manager (KEDA scaler, identity) |
| `*.identity.azure.net` | 443 | HTTPS | Managed Identity token endpoint |
| `*.login.microsoft.com` | 443 | HTTPS | Azure AD authentication (fallback) |

---

## Azure Container Apps Infrastructure

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `*.azurecontainerapps.dev` | 443 | HTTPS | Container Apps platform (internal) |
| `*.servicebus.windows.net` | 443 | HTTPS | Container Apps KEDA scaler connectivity |

---

## Network Rules (non-HTTP)

| Destination | Port | Protocol | Purpose |
|---|---|---|---|
| `AzureMonitor` (service tag) | 443 | TCP | Log Analytics data ingestion |
| `AzureActiveDirectory` (service tag) | 443 | TCP | Entra ID authentication |
| `AzureContainerRegistry` (service tag) | 443 | TCP | ACR connectivity |

---

## Recommended Azure Firewall Application Rule Collection

```text
Rule Collection: rc-cicd-runners
Priority: 200
Action: Allow

Rules:
  - Name: github-runners
    Source: <container-app-subnet-cidr>
    FQDNs: github.com, api.github.com, *.actions.githubusercontent.com,
           codeload.github.com, *.pkg.github.com, ghcr.io,
           results-receiver.actions.githubusercontent.com,
           pipelines.actions.githubusercontent.com,
           objects.githubusercontent.com, raw.githubusercontent.com
    Protocol: Https:443

  - Name: azuredevops-agents
    Source: <container-app-subnet-cidr>
    FQDNs: dev.azure.com, *.dev.azure.com, *.vsassets.io,
           *.visualstudio.com, vstsagentpackage.azureedge.net,
           *.vstsmms.visualstudio.com
    Protocol: Https:443

  - Name: azure-platform
    Source: <container-app-subnet-cidr>
    FQDNs: login.microsoftonline.com, management.azure.com,
           *.identity.azure.net, *.login.microsoft.com
    Protocol: Https:443

  - Name: container-registry
    Source: <container-app-subnet-cidr>
    FQDNs: *.azurecr.io, *.blob.core.windows.net,
           mcr.microsoft.com, *.data.mcr.microsoft.com,
           packages.microsoft.com
    Protocol: Https:443

  - Name: container-apps-platform
    Source: <container-app-subnet-cidr>
    FQDNs: *.azurecontainerapps.dev, *.servicebus.windows.net
    Protocol: Https:443
```

---

## Validation

After configuring firewall rules, you can validate connectivity by running a test workflow:

**GitHub Actions:**
```yaml
jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -s https://api.github.com/zen
          echo "Connectivity OK"
```

**Azure DevOps:**
```yaml
pool: <your-pool-name>
steps:
  - script: |
      curl -s https://dev.azure.com
      echo "Connectivity OK"
```

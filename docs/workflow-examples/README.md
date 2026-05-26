# Workflow examples

Drop-in `.github/workflows/*.yml` files that work with the runners deployed by this module. Both rely on the **runner UAMI** for Azure authentication — no PATs, no client secrets.

## [`container-build.yml`](./container-build.yml)

Build a container image and push it to ACR using `az acr build`. The build runs inside ACR Tasks (no Docker daemon on the runner), making it compatible with the daemon-less, non-privileged runner image this module ships.

**When to use:** Any container image build that targets your central ACR.

**What the runner needs:**

- `AcrPush` (or scope map permission on the target namespace) on the ACR
- Network reachability to the ACR data plane (typically via private endpoint)

## [`terraform-apply.yml`](./terraform-apply.yml)

Plan-and-apply pattern for Terraform IaC using `ARM_USE_MSI=true` so the azurerm provider picks up the runner's managed identity. State is assumed to live in a Storage Account in the platform LZ.

**When to use:** Landing-zone or workload Terraform deploys originating from a workload subscription's pipeline.

**What the runner needs:**

- RBAC on the target subscription (Contributor or a tighter custom role)
- Data-plane access to the Terraform state Storage Account
- A protected `production` environment in the repo (recommended) for the apply gate

## Runner labels

Both examples target `runs-on: [self-hosted, linux, alz-corp]`. Adjust the labels to match the registration tags configured on the runner pool in your deployment.

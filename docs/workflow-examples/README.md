# Workflow examples

Drop-in `.github/workflows/*.yml` files that work with the runners deployed by this module. They rely on the **runner UAMI** for Azure authentication. No PATs, no client secrets.

## [`terraform-apply.yml`](./terraform-apply.yml)

Plan-and-apply pattern for Terraform IaC using `ARM_USE_MSI=true` so the azurerm provider picks up the runner's managed identity. State is assumed to live in a Storage Account in the platform LZ.

**When to use:** Landing-zone or workload Terraform deploys originating from a workload subscription's pipeline.

**What the runner needs:**

- RBAC on the target subscription (Contributor or a tighter custom role)
- Data-plane access to the Terraform state Storage Account
- A protected `production` environment in the repo (recommended) for the apply gate

## More patterns

For container build patterns (private ACR, agent pools, Buildah) and other end-to-end recipes, see the companion repo: [`github-runners-alz-corp-cookbook`](https://github.com/martinopedal/github-runners-alz-corp-cookbook).

## Runner labels

Both examples target `runs-on: [self-hosted, linux, alz-corp]`. Adjust the labels to match the registration tags configured on the runner pool in your deployment.

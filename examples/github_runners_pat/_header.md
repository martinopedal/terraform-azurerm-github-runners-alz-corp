# GitHub Runners with PAT authentication

Deploys self-hosted GitHub Actions runners on Azure Container Apps using a Personal Access Token for runner registration. Grants `AcrPush` to the runner UAMI on the created Container Registry so workflows can run `az acr build`.

Networking inputs (VNet subnets and the private DNS zone for the registry) are expected from the ALZ Vending Module.

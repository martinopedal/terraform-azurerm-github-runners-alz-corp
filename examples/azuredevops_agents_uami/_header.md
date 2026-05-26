# Azure DevOps Agents with UAMI authentication

Deploys self-hosted Azure DevOps agents on Azure Container Apps using a User Assigned Managed Identity for agent registration. No PAT to rotate.

Prereq: the UAMI must be registered as a service principal in your Azure DevOps organization and granted `Administrator` on the target agent pool before the agents will register. Networking inputs are expected from the ALZ Vending Module.

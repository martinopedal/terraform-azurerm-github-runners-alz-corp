terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }
}

provider "azurerm" {
  features {}

  # Required because the webhook Storage Account is created with
  # shared_access_key_enabled = false. Without this flag, the azurerm provider
  # tries to read queue properties via the storage shared-key data-plane API
  # and fails with 403 on AAD-only accounts. See WEBHOOKS.md.
  storage_use_azuread = true
}

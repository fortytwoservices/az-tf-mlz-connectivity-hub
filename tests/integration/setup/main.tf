# A name suffix and the subscription for one integration test run; the module creates its own resource
# groups, named rg-mlz-hub-it-<suffix> and rg-mlz-hub-it-pdns-<suffix>.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

output "location" {
  value = "swedencentral"
}

output "parent_id" {
  value = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
}

output "suffix" {
  value = random_string.suffix.result
}

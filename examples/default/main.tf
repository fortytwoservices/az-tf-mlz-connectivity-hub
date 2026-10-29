# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "default" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# The diagnostic settings' destination, normally the management state's workspace.
resource "azapi_resource" "monitoring" {
  type      = "Microsoft.Resources/resourceGroups@2025-04-01"
  name      = "rg-mlz-hub-ex-mon-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2025-07-01"
  name      = "law-mlz-hub-ex-${random_string.suffix.result}"
  parent_id = azapi_resource.monitoring.id
  location  = local.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

module "connectivity" {
  source = "../../"

  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  # Every name comes from the template, except the resource groups'.
  naming = {
    template  = "$${slug}$${separator}mlz$${separator}$${region}$${separator}$${run_id}"
    variables = { run_id = random_string.suffix.result }
  }
  hub_virtual_networks = {
    swedencentral = {
      location            = local.location
      address_space       = ["10.100.0.0/22"]
      is_primary          = true
      resource_group_name = "rg-mlz-hub-ex-${random_string.suffix.result}"
      routing_supernet    = ["10.100.0.0/16"]
      # Each spoke's exact prefix: on-premises traffic to it goes through the firewall.
      spoke_address_prefixes = { app1 = "10.100.8.0/24" }
      # Basic keeps this example cheap to test; a production hub uses Standard or Premium. Basic needs the
      # management NIC and has no DNS proxy, so spokes resolve through the resolver.
      firewall = {
        sku_tier                         = "Basic"
        subnet_address_prefix            = "10.100.0.0/26"
        management_subnet_address_prefix = "10.100.0.64/26"
      }
      # The firewall's outbound path: StandardV2, zone-redundant.
      nat_gateway = {}
      dns_resolver = {
        inbound_subnet_address_prefix  = "10.100.1.64/28"
        outbound_subnet_address_prefix = "10.100.1.80/28"
      }
    }
  }
  # Two of the Private Link zones, linked to the hub; leave out the filter for all of them.
  private_dns_zones = {
    resource_group_name = "rg-mlz-hub-ex-pdns-${random_string.suffix.result}"
    zone_name_filter    = "^privatelink\\.(blob\\.core|vaultcore)\\."
  }
  diagnostic_settings = {
    workspace = {
      workspace_resource_id = azapi_resource.workspace.id
      logs                  = [{ category_group = "allLogs" }]
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  tags = local.tags
}

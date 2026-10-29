# Names from a template, through Azure/avm-utl-naming (pure: no Azure calls) with this module's override
# file, and Azure/avm-utl-regions' cached data. Only locals are asserted: the components are overridden.
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/azureFirewalls/afw-sdc"
      output = { properties = { ipAddress = "20.0.0.1", ipConfigurations = [{ properties = { privateIPAddress = "10.100.0.4" } }] } }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

override_resource {
  target = azapi_resource.resource_group
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc" }
}
override_resource {
  target = azapi_resource.private_dns_resource_group
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-pdns" }
}
override_module {
  target = module.hub_virtual_network
  outputs = {
    name        = "vnet-sdc"
    resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc"
    subnets = {
      firewall            = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/AzureFirewallSubnet" }
      firewall_management = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/AzureFirewallManagementSubnet" }
      gateway             = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/GatewaySubnet" }
    }
  }
}
override_module {
  target  = module.firewall_route_table
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/routeTables/rt-afw-sdc" }
}
override_module {
  target  = module.gateway_route_table
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/routeTables/rt-vgw-sdc" }
}
override_module {
  target  = module.nat_gateway
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/natGateways/ng-sdc" }
}
override_module {
  target  = module.bastion
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/bastionHosts/bas-sdc" }
}
override_module {
  target  = module.dns_resolver
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/dnsResolvers/dnspr-sdc" }
}
override_module {
  target  = module.vpn_gateway
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworkGateways/vgw-sdc" }
}
override_module {
  target  = module.express_route_gateway
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworkGateways/ergw-sdc" }
}
override_module {
  target  = module.private_dns_zones
  outputs = { private_dns_zone_resource_ids = {} }
}

variables {
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  naming = {
    template  = "az$${separator}$${slug}$${separator}$${landing_zone}$${separator}$${region}$${separator}$${instance}"
    variables = { landing_zone = "conn" }
    instance  = 1
  }
  private_dns_zones = { zone_name_filter = "^privatelink\\.blob\\." }
  hub_virtual_networks = {
    swedencentral = {
      location                      = "swedencentral"
      address_space                 = ["10.100.0.0/22"]
      is_primary                    = true
      gateway_subnet_address_prefix = "10.100.1.0/26"
      firewall = {
        subnet_address_prefix            = "10.100.0.0/26"
        management_subnet_address_prefix = "10.100.0.64/26"
      }
      nat_gateway  = {}
      bastion      = { subnet_address_prefix = "10.100.0.128/26" }
      dns_resolver = { inbound_subnet_address_prefix = "10.100.1.64/28", outbound_subnet_address_prefix = "10.100.1.80/28" }
      vpn_gateway = {
        active_active = true
        point_to_site = { address_space = ["172.16.0.0/24"], root_certificates = { root = "MIIC" } }
      }
      express_route_gateway = {}
    }
  }
}

run "template_names" {
  command = apply

  assert {
    condition = jsonencode(local.names.swedencentral) == jsonencode({
      bastion                        = "az-bas-conn-sdc-001"
      bastion_public_ip              = "az-pip-bas-conn-sdc-001"
      dns_resolver                   = "az-dnspr-conn-sdc-001"
      dns_resolver_inbound_endpoint  = "az-in-conn-sdc-001"
      dns_resolver_outbound_endpoint = "az-out-conn-sdc-001"
      express_route_gateway          = "az-ergw-conn-sdc-001"
      firewall                       = "az-afw-conn-sdc-001"
      firewall_management_public_ip  = "az-pip-afwm-conn-sdc-001"
      firewall_policy                = "az-afwp-conn-sdc-001"
      firewall_public_ip             = "az-pip-afw-conn-sdc-001"
      firewall_route_table           = "az-rt-afw-conn-sdc-001"
      gateway_route_table            = "az-rt-vgw-conn-sdc-001"
      nat_gateway                    = "az-ng-conn-sdc-001"
      nat_gateway_public_ip          = "az-pip-ng-conn-sdc-001"
      resource_group                 = "az-rg-conn-sdc-001"
      virtual_network                = "az-vnet-conn-sdc-001"
      vpn_gateway                    = "az-vgw-conn-sdc-001"
      vpn_gateway_public_ip_1        = "az-pip-vgw1-conn-sdc-001"
      vpn_gateway_public_ip_2        = "az-pip-vgw2-conn-sdc-001"
      vpn_gateway_public_ip_3        = "az-pip-vgw3-conn-sdc-001"
    })
    error_message = "Every component should be named from the template, with the region's short name and a slug per role: ${jsonencode(local.names.swedencentral)}."
  }
  assert {
    condition     = local.private_dns_resource_group_name == "az-rg-pdns-conn-sdc-001" && azapi_resource.private_dns_resource_group[0].name == local.private_dns_resource_group_name
    error_message = "The private DNS zones' resource group should be named from the primary hub's template: ${jsonencode(local.private_dns_resource_group_name)}."
  }
}

run "explicit_names_win" {
  command = apply

  variables {
    private_dns_zones = { resource_group_name = "rg-pdns-explicit", zone_name_filter = "^privatelink\\.blob\\." }
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-explicit"
        resource_group_name = "rg-explicit"
        firewall = {
          name                  = "afw-explicit"
          subnet_address_prefix = "10.100.0.0/26"
          public_ip_name        = "pip-afw-explicit"
          route_table_name      = "rt-afw-explicit"
          firewall_policy       = { name = "afwp-explicit" }
        }
        gateway_subnet_address_prefix = "10.100.1.0/27"
        gateway_route_table_name      = "rt-vgw-explicit"
        vpn_gateway                   = { name = "vgw-explicit", public_ip_names = ["pip-vgw-explicit"] }
      }
    }
  }

  assert {
    condition = jsonencode(local.names.swedencentral) == jsonencode({
      firewall                = "afw-explicit"
      firewall_policy         = "afwp-explicit"
      firewall_public_ip      = "pip-afw-explicit"
      firewall_route_table    = "rt-afw-explicit"
      gateway_route_table     = "rt-vgw-explicit"
      resource_group          = "rg-explicit"
      virtual_network         = "vnet-explicit"
      vpn_gateway             = "vgw-explicit"
      vpn_gateway_public_ip_1 = "pip-vgw-explicit"
    })
    error_message = "Explicit names should win over the template: ${jsonencode(local.names.swedencentral)}."
  }
  assert {
    condition     = local.private_dns_resource_group_name == "rg-pdns-explicit"
    error_message = "An explicit private DNS resource group name should win over the template."
  }
}

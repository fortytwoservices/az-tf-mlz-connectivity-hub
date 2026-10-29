# The composition's wiring: subnets, routes, peerings, DNS, names and the contract. The building blocks
# are tested in their own repositories and overridden here (mocks give their resources IDs their own
# validations refuse), except the firewall module, which runs so its validations check what this module
# passes; the mock gives it the address the routes expect for `10.100.0.0/26`.
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
      firewall              = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/AzureFirewallSubnet" }
      firewall_management   = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/AzureFirewallManagementSubnet" }
      gateway               = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/GatewaySubnet" }
      bastion               = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/AzureBastionSubnet" }
      dns_resolver_inbound  = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/snet-dns-resolver-inbound" }
      dns_resolver_outbound = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/subnets/snet-dns-resolver-outbound" }
    }
  }
}
override_module {
  target  = module.hub_peering
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworks/vnet-sdc/virtualNetworkPeerings/peer" }
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
  target = module.nat_gateway
  outputs = {
    resource_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/natGateways/ng-sdc"
    public_ip_addresses = { ipv4 = "20.0.0.3" }
  }
}
override_module {
  target  = module.bastion
  outputs = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/bastionHosts/bas-sdc" }
}
override_module {
  target = module.dns_resolver
  outputs = {
    resource_id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/dnsResolvers/dnspr-sdc"
    outbound_endpoint_resource_ids = { outbound = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/dnsResolvers/dnspr-sdc/outboundEndpoints/out-sdc" }
  }
}
override_module {
  target = module.vpn_gateway
  outputs = {
    resource_id                        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworkGateways/vgw-sdc"
    public_ip_addresses                = { ipconfig1 = "20.0.0.4" }
    bgp_settings                       = { asn = 65515, peering_addresses = {} }
    connection_resource_ids            = {}
    local_network_gateway_resource_ids = {}
  }
}
override_module {
  target = module.express_route_gateway
  outputs = {
    resource_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/virtualNetworkGateways/ergw-sdc"
    connection_resource_ids = {}
  }
}
override_module {
  target = module.private_dns_zones
  outputs = {
    private_dns_zone_resource_ids = {
      azure_storage_blob = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-pdns/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    }
  }
}

variables {
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  hub_virtual_networks = {
    swedencentral = {
      location            = "swedencentral"
      address_space       = ["10.100.0.0/22"]
      is_primary          = true
      name                = "vnet-sdc"
      resource_group_name = "rg-sdc"
    }
  }
}

run "minimal_hub" {
  command = apply

  assert {
    condition     = azapi_resource.resource_group["swedencentral"].type == "Microsoft.Resources/resourceGroups@2025-04-01" && azapi_resource.resource_group["swedencentral"].name == "rg-sdc" && azapi_resource.resource_group["swedencentral"].parent_id == var.parent_id && azapi_resource.resource_group["swedencentral"].location == "swedencentral"
    error_message = "One resource group per hub should be created in the subscription and the hub's region."
  }
  assert {
    condition     = jsonencode(azapi_resource.resource_group["swedencentral"].retry.error_message_regex) == jsonencode(["AnotherOperationInProgress", "ReferencedResourceNotProvisioned", "CannotDeleteResource"]) && azapi_resource.resource_group["swedencentral"].timeouts.create == "90m" && azapi_resource.resource_group["swedencentral"].timeouts.delete == "90m"
    error_message = "retry and timeouts should default to what the composition's resources need."
  }
  assert {
    condition     = jsonencode(local.hub_subnets.swedencentral) == jsonencode({}) && length(local.hub_peerings) == 0 && length(local.firewall_routes) == 0 && length(local.gateway_route_tables) == 0
    error_message = "A hub without components should have no subnets, peerings or route tables."
  }
  assert {
    condition     = length(azapi_resource.private_dns_resource_group) == 0 && length(module.private_dns_zones) == 0
    error_message = "No private DNS zones should be created by default."
  }
  assert {
    condition = jsonencode(output.connectivity.regions.swedencentral) == jsonencode({
      is_primary              = true
      routing_supernet        = []
      hub_virtual_network_id  = output.resource_id
      virtual_hub_id          = null
      vhub_route_table_ids    = null
      routing_intent_enabled  = false
      firewall_private_ip     = null
      firewall_policy_id      = null
      dns_servers             = []
      ipam_pool_id            = null
      ddos_protection_plan_id = null
      spoke_default_routes    = null
    })
    error_message = "The contract of a hub without components should hold only the hub: ${jsonencode(output.connectivity.regions.swedencentral)}."
  }
  assert {
    condition     = output.connectivity.topology == "hub_and_spoke" && output.connectivity.connectivity_subscription_id == "00000000-0000-0000-0000-000000000000" && output.connectivity.base_firewall_policy_id == null && output.connectivity.private_dns_zone_ids == null && output.connectivity.private_dns_resource_group_id == null
    error_message = "The contract should name the topology and the subscription, and no private DNS zones."
  }
  assert {
    condition     = output.name == "vnet-sdc" && output.hub_virtual_networks.swedencentral.resource_group_id == azapi_resource.resource_group["swedencentral"].id && output.hub_virtual_networks.swedencentral.firewall_resource_id == null && output.hub_virtual_networks.swedencentral.vpn_gateway_resource_id == null
    error_message = "The outputs should show the hub and no components."
  }
}

run "full_hub" {
  command   = apply
  state_key = "full_hub"

  variables {
    ddos_protection_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ddos/providers/Microsoft.Network/ddosProtectionPlans/ddos"
    private_dns_zones       = { resource_group_name = "rg-pdns", zone_name_filter = "^privatelink\\.blob\\." }
    diagnostic_settings = {
      law = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mgmt/providers/Microsoft.OperationalInsights/workspaces/law"
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
      logs_only = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mgmt/providers/Microsoft.OperationalInsights/workspaces/law"
        logs                  = [{ category_group = "audit" }]
      }
    }
    hub_virtual_networks = {
      swedencentral = {
        location                      = "swedencentral"
        address_space                 = ["10.100.0.0/22"]
        is_primary                    = true
        name                          = "vnet-sdc"
        resource_group_name           = "rg-sdc"
        routing_supernet              = ["10.100.0.0/16"]
        spoke_address_prefixes        = { app1 = "10.100.8.0/24", app2 = "10.100.9.0/24" }
        virtual_network_dns_servers   = ["10.100.1.68"]
        gateway_subnet_address_prefix = "10.100.1.0/26"
        gateway_route_table_name      = "rt-vgw-sdc"
        firewall = {
          name                  = "afw-sdc"
          subnet_address_prefix = "10.100.0.0/26"
          public_ip_name        = "pip-afw-sdc"
          route_table_name      = "rt-afw-sdc"
          firewall_policy       = { name = "afwp-sdc", base_policy_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/firewallPolicies/afwp-base" }
        }
        nat_gateway  = { name = "ng-sdc", public_ip_name = "pip-ng-sdc" }
        bastion      = { name = "bas-sdc", subnet_address_prefix = "10.100.0.128/26", public_ip_name = "pip-bas-sdc" }
        dns_resolver = { name = "dnspr-sdc", inbound_subnet_address_prefix = "10.100.1.64/28", inbound_endpoint_name = "in-sdc", outbound_subnet_address_prefix = "10.100.1.80/28", outbound_endpoint_name = "out-sdc" }
        vpn_gateway = {
          name            = "vgw-sdc"
          active_active   = true
          bgp             = {}
          point_to_site   = { address_space = ["172.16.0.0/24"], root_certificates = { root = "MIIC" } }
          public_ip_names = ["pip-vgw1-sdc", "pip-vgw2-sdc", "pip-vgw3-sdc"]
          local_network_gateways = {
            office = { name = "lgw-office", gateway_ip_address = "203.0.113.10", address_prefixes = ["192.168.0.0/24"] }
          }
          connections = {
            office = { name = "con-office", local_network_gateway_key = "office" }
          }
        }
        express_route_gateway = {
          name                      = "ergw-sdc"
          sku                       = "ErGwScale"
          express_route_scale_units = { min = 1, max = 1 }
        }
      }
    }
  }

  assert {
    condition = jsonencode(local.hub_subnets.swedencentral) == jsonencode({
      bastion = { name = "AzureBastionSubnet", address_prefix = "10.100.0.128/26", retry = var.retry, timeouts = var.timeouts }
      dns_resolver_inbound = {
        name           = "snet-dns-resolver-inbound"
        address_prefix = "10.100.1.64/28"
        delegations    = [{ name = "Microsoft.Network.dnsResolvers", service_delegation = { name = "Microsoft.Network/dnsResolvers" } }]
        retry          = var.retry
        timeouts       = var.timeouts
      }
      dns_resolver_outbound = {
        name           = "snet-dns-resolver-outbound"
        address_prefix = "10.100.1.80/28"
        delegations    = [{ name = "Microsoft.Network.dnsResolvers", service_delegation = { name = "Microsoft.Network/dnsResolvers" } }]
        retry          = var.retry
        timeouts       = var.timeouts
      }
      firewall = {
        name           = "AzureFirewallSubnet"
        address_prefix = "10.100.0.0/26"
        route_table    = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/routeTables/rt-afw-sdc" }
        nat_gateway    = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/natGateways/ng-sdc" }
        retry          = var.retry
        timeouts       = var.timeouts
      }
      gateway = {
        name           = "GatewaySubnet"
        address_prefix = "10.100.1.0/26"
        route_table    = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/routeTables/rt-vgw-sdc" }
        retry          = var.retry
        timeouts       = var.timeouts
      }
    })
    error_message = "Each component should get its subnet, the firewall's and the gateway's with their route tables and the NAT gateway on the firewall's: ${jsonencode(local.hub_subnets.swedencentral)}."
  }
  assert {
    condition = jsonencode(local.firewall_routes.swedencentral) == jsonencode({
      default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet", next_hop_in_ip_address = null }
    })
    error_message = "A single hub's firewall subnet should route only the default route, to the Internet: ${jsonencode(local.firewall_routes.swedencentral)}."
  }
  assert {
    condition = jsonencode(local.gateway_routes.swedencentral) == jsonencode({
      spoke-app1 = { name = "spoke-app1", address_prefix = "10.100.8.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      spoke-app2 = { name = "spoke-app2", address_prefix = "10.100.9.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    })
    error_message = "GatewaySubnet should route each spoke to the firewall: ${jsonencode(local.gateway_routes.swedencentral)}."
  }
  assert {
    condition = jsonencode(local.firewall_policies.swedencentral) == jsonencode({
      name                     = "afwp-sdc"
      base_policy_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/firewallPolicies/afwp-base"
      threat_intelligence_mode = "Alert"
      dns                      = { proxy_enabled = true, servers = ["10.100.1.68"] }
    })
    error_message = "A Standard firewall's policy should proxy DNS to the resolver's inbound address."
  }
  assert {
    condition     = local.vpn_gateway_ip_configuration_counts.swedencentral == 3 && local.names.swedencentral.vpn_gateway_public_ip_3 == "pip-vgw3-sdc"
    error_message = "An active-active gateway with point-to-site should get three IP configurations, named in order."
  }
  assert {
    condition = jsonencode(output.connectivity.regions.swedencentral) == jsonencode({
      is_primary              = true
      routing_supernet        = ["10.100.0.0/16"]
      hub_virtual_network_id  = output.resource_id
      virtual_hub_id          = null
      vhub_route_table_ids    = null
      routing_intent_enabled  = false
      firewall_private_ip     = "10.100.0.4"
      firewall_policy_id      = output.hub_virtual_networks.swedencentral.firewall_policy_resource_id
      dns_servers             = ["10.100.0.4"]
      ipam_pool_id            = null
      ddos_protection_plan_id = var.ddos_protection_plan_id
      spoke_default_routes    = { default = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" } }
    })
    error_message = "The contract should give the firewall as next hop and DNS server, and the DDoS plan: ${jsonencode(output.connectivity.regions.swedencentral)}."
  }
  assert {
    condition     = output.connectivity.base_firewall_policy_id == var.hub_virtual_networks.swedencentral.firewall.firewall_policy.base_policy_id
    error_message = "The contract should give the primary hub's base policy."
  }
  assert {
    condition     = jsonencode(output.connectivity.private_dns_zone_ids) == jsonencode({ "privatelink.blob.core.windows.net" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-pdns/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" }) && output.connectivity.private_dns_resource_group_id == azapi_resource.private_dns_resource_group[0].id
    error_message = "The contract should give the private DNS zones by name and their resource group."
  }
  assert {
    condition     = azapi_resource.private_dns_resource_group[0].name == "rg-pdns" && azapi_resource.private_dns_resource_group[0].location == "swedencentral" && jsonencode(keys(module.private_dns_zones)) == jsonencode(["swedencentral"])
    error_message = "The private DNS zones should get their own resource group in the primary region."
  }
  assert {
    condition     = jsonencode(keys(local.dns_resolver_diagnostic_settings)) == jsonencode(["law"]) && length(local.dns_resolver_diagnostic_settings.law.logs) == 0
    error_message = "The resolver should get only the settings with metrics, without logs."
  }
  assert {
    condition     = output.hub_virtual_networks.swedencentral.vpn_gateway_resource_id == module.vpn_gateway["swedencentral"].resource_id && output.hub_virtual_networks.swedencentral.express_route_gateway_resource_id == module.express_route_gateway["swedencentral"].resource_id && output.hub_virtual_networks.swedencentral.gateway_route_table_resource_id == module.gateway_route_table["swedencentral"].resource_id
    error_message = "The outputs should show both gateways and the gateway route table."
  }
  assert {
    condition     = output.hub_virtual_networks.swedencentral.nat_gateway_resource_id == module.nat_gateway["swedencentral"].resource_id && output.hub_virtual_networks.swedencentral.dns_resolver_outbound_endpoint_resource_id == module.dns_resolver["swedencentral"].outbound_endpoint_resource_ids.outbound
    error_message = "The outputs should show the NAT gateway and the resolver's outbound endpoint."
  }
}

# Two firewalled hubs: every hub peered with the other, each region's summary routed to its firewall.
run "two_hubs_meshed" {
  command   = apply
  state_key = "mesh"

  override_module {
    target  = module.firewall["norwayeast"]
    outputs = { private_ip_address = "10.200.0.4" }
  }

  variables {
    hub_virtual_networks = {
      swedencentral = {
        location                      = "swedencentral"
        address_space                 = ["10.100.0.0/22"]
        is_primary                    = true
        name                          = "vnet-sdc"
        resource_group_name           = "rg-sdc"
        routing_supernet              = ["10.100.0.0/16"]
        spoke_address_prefixes        = { app1 = "10.100.8.0/24" }
        gateway_subnet_address_prefix = "10.100.1.0/27"
        gateway_route_table_name      = "rt-vgw-sdc"
        firewall                      = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/26", public_ip_name = "pip-afw-sdc", route_table_name = "rt-afw-sdc", firewall_policy = { name = "afwp-sdc" } }
        vpn_gateway                   = { name = "vgw-sdc", public_ip_names = ["pip-vgw1-sdc"] }
      }
      norwayeast = {
        location            = "norwayeast"
        address_space       = ["10.200.0.0/22"]
        name                = "vnet-nwe"
        resource_group_name = "rg-nwe"
        routing_supernet    = ["10.200.0.0/16", "10.201.0.0/16"]
        firewall            = { name = "afw-nwe", subnet_address_prefix = "10.200.0.0/26", public_ip_name = "pip-afw-nwe", route_table_name = "rt-afw-nwe", firewall_policy = { name = "afwp-nwe" } }
      }
    }
  }

  assert {
    condition = jsonencode(local.hub_peerings) == jsonencode({
      norwayeast-to-swedencentral = { local = "norwayeast", remote = "swedencentral" }
      swedencentral-to-norwayeast = { local = "swedencentral", remote = "norwayeast" }
    })
    error_message = "Each hub should be peered with the other: ${jsonencode(local.hub_peerings)}."
  }
  assert {
    condition = jsonencode(local.firewall_routes.swedencentral) == jsonencode({
      default                        = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet", next_hop_in_ip_address = null }
      "hub-norwayeast-10.200.0.0_16" = { name = "hub-norwayeast-10.200.0.0_16", address_prefix = "10.200.0.0/16", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.200.0.4" }
      "hub-norwayeast-10.201.0.0_16" = { name = "hub-norwayeast-10.201.0.0_16", address_prefix = "10.201.0.0/16", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.200.0.4" }
    })
    error_message = "The firewall subnet should route the other region to that region's firewall: ${jsonencode(local.firewall_routes.swedencentral)}."
  }
  assert {
    condition = jsonencode(local.firewall_routes.norwayeast) == jsonencode({
      default                           = { name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "Internet", next_hop_in_ip_address = null }
      "hub-swedencentral-10.100.0.0_16" = { name = "hub-swedencentral-10.100.0.0_16", address_prefix = "10.100.0.0/16", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    })
    error_message = "Both hubs should route the other's summary: ${jsonencode(local.firewall_routes.norwayeast)}."
  }
  assert {
    condition = jsonencode(local.gateway_routes.swedencentral) == jsonencode({
      "hub-norwayeast-10.200.0.0_16" = { name = "hub-norwayeast-10.200.0.0_16", address_prefix = "10.200.0.0/16", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      "hub-norwayeast-10.201.0.0_16" = { name = "hub-norwayeast-10.201.0.0_16", address_prefix = "10.201.0.0/16", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
      spoke-app1                     = { name = "spoke-app1", address_prefix = "10.100.8.0/24", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.100.0.4" }
    })
    error_message = "GatewaySubnet should send the spokes and the other region to the local firewall: ${jsonencode(local.gateway_routes.swedencentral)}."
  }
  assert {
    condition     = jsonencode(keys(local.gateway_route_tables)) == jsonencode(["swedencentral"]) && output.connectivity.regions.norwayeast.firewall_private_ip == "10.200.0.4" && !output.connectivity.regions.norwayeast.is_primary
    error_message = "Only the hub with a gateway should get a gateway route table; each region its own firewall."
  }
  assert {
    condition     = jsonencode(output.hub_virtual_networks.swedencentral.peering_resource_ids) == jsonencode({ norwayeast = module.hub_peering["swedencentral-to-norwayeast"].resource_id })
    error_message = "The outputs should show each hub's peering by remote hub."
  }
}

run "mesh_peering_disabled" {
  command   = apply
  state_key = "mesh"

  override_module {
    target  = module.firewall["norwayeast"]
    outputs = { private_ip_address = "10.200.0.4" }
  }

  variables {
    mesh_peering_enabled = false
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-sdc"
        resource_group_name = "rg-sdc"
        routing_supernet    = ["10.100.0.0/16"]
        firewall            = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/26", public_ip_name = "pip-afw-sdc", route_table_name = "rt-afw-sdc", firewall_policy = { name = "afwp-sdc" } }
      }
      norwayeast = {
        location            = "norwayeast"
        address_space       = ["10.200.0.0/22"]
        name                = "vnet-nwe"
        resource_group_name = "rg-nwe"
        routing_supernet    = ["10.200.0.0/16"]
        firewall            = { name = "afw-nwe", subnet_address_prefix = "10.200.0.0/26", public_ip_name = "pip-afw-nwe", route_table_name = "rt-afw-nwe", firewall_policy = { name = "afwp-nwe" } }
      }
    }
  }

  assert {
    condition     = length(local.hub_peerings) == 0 && jsonencode(keys(local.firewall_routes.swedencentral)) == jsonencode(["default"]) && jsonencode(keys(local.firewall_routes.norwayeast)) == jsonencode(["default"])
    error_message = "Without the mesh, hubs should be neither peered nor routed to each other."
  }
}

# Forced tunnelling through an appliance, then through the gateway's BGP-learned default route.
run "forced_tunnelling" {
  command   = apply
  state_key = "forced"

  variables {
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-sdc"
        resource_group_name = "rg-sdc"
        firewall = {
          name                             = "afw-sdc"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-sdc"
          management_public_ip_name        = "pip-afwm-sdc"
          route_table_name                 = "rt-afw-sdc"
          default_route                    = { next_hop_type = "VirtualAppliance", next_hop_ip_address = "192.168.10.4" }
          firewall_policy                  = { name = "afwp-sdc" }
        }
      }
    }
  }

  assert {
    condition     = jsonencode(local.firewall_routes.swedencentral.default) == jsonencode({ name = "default", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "192.168.10.4" })
    error_message = "The firewall subnet's default route should go to the appliance."
  }
  assert {
    condition     = jsonencode(local.hub_subnets.swedencentral.firewall_management) == jsonencode({ name = "AzureFirewallManagementSubnet", address_prefix = "10.100.0.64/26", retry = var.retry, timeouts = var.timeouts })
    error_message = "The management subnet should get no route table."
  }
}

run "forced_tunnelling_through_bgp" {
  command   = apply
  state_key = "forced"

  variables {
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-sdc"
        resource_group_name = "rg-sdc"
        firewall = {
          name                             = "afw-sdc"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-sdc"
          management_public_ip_name        = "pip-afwm-sdc"
          route_table_name                 = "rt-afw-sdc"
          default_route                    = { enabled = false }
          firewall_policy                  = { name = "afwp-sdc" }
        }
      }
    }
  }

  assert {
    condition     = length(local.firewall_routes.swedencentral) == 0
    error_message = "Without a default route, the firewall subnet's table should hold no route (a BGP-learned default applies)."
  }
}

# Basic: management NIC, no DNS proxy, spokes resolve through the resolver.
run "basic_firewall" {
  command   = apply
  state_key = "basic"

  variables {
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-sdc"
        resource_group_name = "rg-sdc"
        firewall = {
          name                             = "afw-sdc"
          sku_tier                         = "Basic"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-sdc"
          management_public_ip_name        = "pip-afwm-sdc"
          route_table_name                 = "rt-afw-sdc"
          firewall_policy                  = { name = "afwp-sdc" }
        }
        dns_resolver = { name = "dnspr-sdc", inbound_subnet_address_prefix = "10.100.1.64/28", inbound_endpoint_name = "in-sdc" }
      }
    }
  }

  assert {
    condition     = jsonencode(local.firewall_policies.swedencentral.dns) == jsonencode({ proxy_enabled = false, servers = [] }) && jsonencode(output.connectivity.regions.swedencentral.dns_servers) == jsonencode(["10.100.1.68"])
    error_message = "A Basic firewall's policy should have no DNS settings, and spokes should use the resolver."
  }
}

run "existing_firewall_policy" {
  command   = apply
  state_key = "existing_policy"

  variables {
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-sdc"
        resource_group_name = "rg-sdc"
        firewall = {
          name                  = "afw-sdc"
          subnet_address_prefix = "10.100.0.0/26"
          public_ip_name        = "pip-afw-sdc"
          route_table_name      = "rt-afw-sdc"
          firewall_policy_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-sdc/providers/Microsoft.Network/firewallPolicies/afwp-shared"
        }
      }
    }
  }

  assert {
    condition     = local.firewall_policies.swedencentral == null && !contains(keys(local.names.swedencentral), "firewall_policy") && jsonencode(output.connectivity.regions.swedencentral.dns_servers) == jsonencode([])
    error_message = "With an existing policy, no policy should be created or named, and spokes should get no DNS server from the module."
  }
}

# The routes assume the subnet's fifth address; Azure's must match.
run "firewall_address_mismatch" {
  command   = plan
  state_key = "mismatch"

  override_module {
    target  = module.firewall["swedencentral"]
    outputs = { private_ip_address = "10.100.0.5" }
  }

  variables {
    hub_virtual_networks = {
      swedencentral = {
        location            = "swedencentral"
        address_space       = ["10.100.0.0/22"]
        is_primary          = true
        name                = "vnet-sdc"
        resource_group_name = "rg-sdc"
        firewall            = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/26", public_ip_name = "pip-afw-sdc", route_table_name = "rt-afw-sdc", firewall_policy = { name = "afwp-sdc" } }
      }
    }
  }

  expect_failures = [output.connectivity]
}

run "private_dns_zones_in_every_region" {
  command   = apply
  state_key = "pdns"

  # The secondary region's call creates its regional zones.
  override_module {
    target = module.private_dns_zones["norwayeast"]
    outputs = {
      private_dns_zone_resource_ids = {
        azure_backup = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-pdns/providers/Microsoft.Network/privateDnsZones/privatelink.nwe.backup.windowsazure.com"
      }
    }
  }

  variables {
    private_dns_zones = { resource_group_name = "rg-pdns" }
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc" }
      norwayeast    = { location = "norwayeast", address_space = ["10.200.0.0/22"], name = "vnet-nwe", resource_group_name = "rg-nwe" }
    }
  }

  assert {
    condition     = jsonencode(keys(module.private_dns_zones)) == jsonencode(["norwayeast", "swedencentral"]) && jsonencode(keys(output.connectivity.private_dns_zone_ids)) == jsonencode(["privatelink.blob.core.windows.net", "privatelink.nwe.backup.windowsazure.com"])
    error_message = "Without a filter, every hub's region should get its zones, all in the contract by name."
  }
}

# Validation.

run "exactly_one_primary" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], name = "vnet-sdc", resource_group_name = "rg-sdc" }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "names_required_without_naming" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", firewall = { subnet_address_prefix = "10.100.0.0/26" } }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "spoke_prefix_not_default_route" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", spoke_address_prefixes = { all = "0.0.0.0/0" } }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "routing_supernet_cidr" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", routing_supernet = ["10.100.0.0"] }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "basic_firewall_dns_settings_refused" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc"
        firewall = { name = "afw-sdc", sku_tier = "Basic", subnet_address_prefix = "10.100.0.0/26", management_subnet_address_prefix = "10.100.0.64/26", public_ip_name = "pip", management_public_ip_name = "pipm", route_table_name = "rt", firewall_policy = { name = "afwp", dns_proxy_enabled = true } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "firewall_subnet_too_small" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc"
        firewall = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/27", public_ip_name = "pip", route_table_name = "rt", firewall_policy = { name = "afwp" } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "basic_firewall_needs_management" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc"
        firewall = { name = "afw-sdc", sku_tier = "Basic", subnet_address_prefix = "10.100.0.0/26", public_ip_name = "pip", route_table_name = "rt", firewall_policy = { name = "afwp" } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "forced_tunnelling_needs_management" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc"
        firewall = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/26", public_ip_name = "pip", route_table_name = "rt", firewall_policy = { name = "afwp" }, default_route = { enabled = false } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "virtual_appliance_needs_address" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc"
        firewall = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/26", management_subnet_address_prefix = "10.100.0.64/26", public_ip_name = "pip", management_public_ip_name = "pipm", route_table_name = "rt", firewall_policy = { name = "afwp" }, default_route = { next_hop_type = "VirtualAppliance" } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "gateway_next_hop_needs_vpn_gateway" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc"
        firewall = { name = "afw-sdc", subnet_address_prefix = "10.100.0.0/26", management_subnet_address_prefix = "10.100.0.64/26", public_ip_name = "pip", management_public_ip_name = "pipm", route_table_name = "rt", firewall_policy = { name = "afwp" }, default_route = { next_hop_type = "VirtualNetworkGateway" } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "nat_gateway_needs_firewall" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", nat_gateway = { name = "ng", public_ip_name = "pip-ng" } }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "bastion_developer_refused" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", bastion = { name = "bas", public_ip_name = "pip-bas", sku = "Developer", subnet_address_prefix = "10.100.0.128/26" } }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "resolver_subnet_too_small" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", dns_resolver = { name = "dnspr", inbound_endpoint_name = "in", inbound_subnet_address_prefix = "10.100.1.64/29" } }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "gateway_needs_gateway_subnet" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", vpn_gateway = { name = "vgw", public_ip_names = ["pip-vgw"] } }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "two_gateways_need_a_26" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location    = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", gateway_subnet_address_prefix = "10.100.1.0/27"
        vpn_gateway = { name = "vgw", public_ip_names = ["pip-vgw"] }, express_route_gateway = { name = "ergw" }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "connection_keys_distinct" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = {
        location              = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-sdc", gateway_subnet_address_prefix = "10.100.1.0/26"
        vpn_gateway           = { name = "vgw", public_ip_names = ["pip-vgw"], connections = { onprem = { name = "con-vpn", peer_virtual_network_gateway_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworkGateways/peer", type = "Vnet2Vnet" } } }
        express_route_gateway = { name = "ergw", connections = { onprem = { name = "con-er", express_route_circuit_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/expressRouteCircuits/erc" } } }
      }
    }
  }
  expect_failures = [var.hub_virtual_networks]
}

run "ddos_plan_id" {
  command = plan
  variables {
    ddos_protection_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/not-a-plan"
  }
  expect_failures = [var.ddos_protection_plan_id]
}

run "parent_id_subscription" {
  command = plan
  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg"
  }
  expect_failures = [var.parent_id]
}

run "resource_group_per_hub" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-sdc", resource_group_name = "rg-hub" }
      norwayeast    = { location = "norwayeast", address_space = ["10.200.0.0/22"], name = "vnet-nwe", resource_group_name = "rg-hub" }
    }
  }
  expect_failures = [azapi_resource.resource_group]
}

run "virtual_network_names_distinct" {
  command = plan
  variables {
    hub_virtual_networks = {
      swedencentral = { location = "swedencentral", address_space = ["10.100.0.0/22"], is_primary = true, name = "vnet-hub", resource_group_name = "rg-sdc" }
      norwayeast    = { location = "norwayeast", address_space = ["10.200.0.0/22"], name = "vnet-hub", resource_group_name = "rg-nwe" }
    }
  }
  expect_failures = [azapi_resource.resource_group]
}

run "private_dns_resource_group_of_its_own" {
  command = plan
  variables {
    private_dns_zones = { resource_group_name = "rg-sdc" }
  }
  expect_failures = [azapi_resource.private_dns_resource_group]
}

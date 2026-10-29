# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# One hub (the user's decision, 2026-10-29: the mesh between hubs is unit-tested only) with a Basic
# firewall (the cheapest tier) and its management NIC, a StandardV2 NAT gateway, a Basic Bastion, a
# resolver, a VpnGw1AZ gateway with a site and a connection, and one private DNS zone; about an hour and a
# half, billed by the hour while it exists, destroyed at the end. Proves what mocks cannot: the building
# blocks fit together in Azure; the routes and subnet associations land; a route table update keeps its
# routes; spoke routes are added and removed; forced tunnelling is switched on and off; custom DNS servers
# are set and removed; the firewall takes its subnet's fifth address; the last plan is clean.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    parent_id          = run.setup.parent_id
    connection_secrets = { "swedencentral/office" = "it-${run.setup.suffix}-shared-key" }
    private_dns_zones  = { resource_group_name = "rg-mlz-hub-it-pdns-${run.setup.suffix}", zone_name_filter = "^privatelink\\.blob\\.core\\." }
    hub_virtual_networks = {
      swedencentral = {
        location                      = run.setup.location
        address_space                 = ["10.100.0.0/22"]
        is_primary                    = true
        name                          = "vnet-mlz-hub-it-${run.setup.suffix}"
        resource_group_name           = "rg-mlz-hub-it-${run.setup.suffix}"
        routing_supernet              = ["10.100.0.0/16"]
        spoke_address_prefixes        = { app1 = "10.100.8.0/24" }
        gateway_subnet_address_prefix = "10.100.1.0/27"
        gateway_route_table_name      = "rt-vgw-mlz-hub-it-${run.setup.suffix}"
        firewall = {
          name                             = "afw-mlz-hub-it-${run.setup.suffix}"
          sku_tier                         = "Basic"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-mlz-hub-it-${run.setup.suffix}"
          management_public_ip_name        = "pip-afwm-mlz-hub-it-${run.setup.suffix}"
          route_table_name                 = "rt-afw-mlz-hub-it-${run.setup.suffix}"
          firewall_policy                  = { name = "afwp-mlz-hub-it-${run.setup.suffix}" }
        }
        nat_gateway = { name = "ng-mlz-hub-it-${run.setup.suffix}", public_ip_name = "pip-ng-mlz-hub-it-${run.setup.suffix}" }
        bastion     = { name = "bas-mlz-hub-it-${run.setup.suffix}", sku = "Basic", subnet_address_prefix = "10.100.0.128/26", public_ip_name = "pip-bas-mlz-hub-it-${run.setup.suffix}" }
        dns_resolver = {
          name                           = "dnspr-mlz-hub-it-${run.setup.suffix}"
          inbound_endpoint_name          = "in-mlz-hub-it-${run.setup.suffix}"
          outbound_endpoint_name         = "out-mlz-hub-it-${run.setup.suffix}"
          inbound_subnet_address_prefix  = "10.100.1.64/28"
          outbound_subnet_address_prefix = "10.100.1.80/28"
        }
        vpn_gateway = {
          name            = "vgw-mlz-hub-it-${run.setup.suffix}"
          public_ip_names = ["pip-vgw-mlz-hub-it-${run.setup.suffix}"]
          local_network_gateways = {
            office = { name = "lgw-mlz-hub-it-${run.setup.suffix}", gateway_ip_address = "203.0.113.10", address_prefixes = ["192.168.0.0/24"] }
          }
          connections = {
            office = { name = "con-mlz-hub-it-${run.setup.suffix}", local_network_gateway_key = "office" }
          }
        }
      }
    }
  }

  assert {
    condition     = output.hub_virtual_networks.swedencentral.firewall_private_ip_address == "10.100.0.4" && output.connectivity.regions.swedencentral.firewall_private_ip == "10.100.0.4"
    error_message = "The firewall should take its subnet's fifth address, got ${output.hub_virtual_networks.swedencentral.firewall_private_ip_address}."
  }
  assert {
    condition     = jsonencode(output.connectivity.regions.swedencentral.dns_servers) == jsonencode(["10.100.1.68"])
    error_message = "With a Basic firewall (no DNS proxy), spokes should use the resolver's inbound address."
  }
  assert {
    condition     = length(output.connectivity.private_dns_zone_ids) == 1 && output.connectivity.private_dns_zone_ids["privatelink.blob.core.windows.net"] != null
    error_message = "The filtered private DNS zone should be created: ${jsonencode(output.connectivity.private_dns_zone_ids)}."
  }
}

run "read_after_create" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    resource_ids = {
      firewall_route_table = "Microsoft.Network/routeTables@2024-05-01|${run.create.hub_virtual_networks.swedencentral.firewall_route_table_resource_id}"
      gateway_route_table  = "Microsoft.Network/routeTables@2024-05-01|${run.create.hub_virtual_networks.swedencentral.gateway_route_table_resource_id}"
      firewall_subnet      = "Microsoft.Network/virtualNetworks/subnets@2024-07-01|${run.create.hub_virtual_networks.swedencentral.subnet_resource_ids.firewall}"
      gateway_subnet       = "Microsoft.Network/virtualNetworks/subnets@2024-07-01|${run.create.hub_virtual_networks.swedencentral.subnet_resource_ids.gateway}"
      firewall             = "Microsoft.Network/azureFirewalls@2025-07-01|${run.create.hub_virtual_networks.swedencentral.firewall_resource_id}"
      connection           = "Microsoft.Network/connections@2025-07-01|${run.create.hub_virtual_networks.swedencentral.vpn_gateway_connection_resource_ids.office}"
      bastion              = "Microsoft.Network/bastionHosts@2025-07-01|${run.create.hub_virtual_networks.swedencentral.bastion_resource_id}"
      private_dns_link     = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01|${run.create.connectivity.private_dns_zone_ids["privatelink.blob.core.windows.net"]}/virtualNetworkLinks/vnet_link-azure_storage_blob-swedencentral"
    }
  }

  assert {
    condition     = jsonencode({ for route in output.properties.firewall_route_table.routes : route.name => [route.properties.addressPrefix, route.properties.nextHopType] }) == jsonencode({ default = ["0.0.0.0/0", "Internet"] }) && output.properties.firewall_route_table.disableBgpRoutePropagation == false
    error_message = "The firewall subnet should route 0.0.0.0/0 to the Internet, with gateway route propagation on: ${jsonencode(output.properties.firewall_route_table)}."
  }
  assert {
    condition     = jsonencode({ for route in output.properties.gateway_route_table.routes : route.name => [route.properties.addressPrefix, route.properties.nextHopType, try(route.properties.nextHopIpAddress, null)] }) == jsonencode({ spoke-app1 = ["10.100.8.0/24", "VirtualAppliance", "10.100.0.4"] }) && output.properties.gateway_route_table.disableBgpRoutePropagation == false
    error_message = "GatewaySubnet should route the spoke to the firewall, with gateway route propagation on: ${jsonencode(output.properties.gateway_route_table)}."
  }
  assert {
    condition     = lower(output.properties.firewall_subnet.routeTable.id) == lower(run.create.hub_virtual_networks.swedencentral.firewall_route_table_resource_id) && lower(output.properties.firewall_subnet.natGateway.id) == lower(run.create.hub_virtual_networks.swedencentral.nat_gateway_resource_id)
    error_message = "AzureFirewallSubnet should have its route table and the NAT gateway."
  }
  assert {
    condition     = lower(output.properties.gateway_subnet.routeTable.id) == lower(run.create.hub_virtual_networks.swedencentral.gateway_route_table_resource_id)
    error_message = "GatewaySubnet should have its route table."
  }
  assert {
    condition     = output.properties.firewall.sku.tier == "Basic" && output.properties.firewall.ipConfigurations[0].properties.privateIPAddress == "10.100.0.4" && output.properties.firewall.managementIpConfiguration != null
    error_message = "The firewall should be a Basic firewall at 10.100.0.4 with its management NIC."
  }
  assert {
    condition     = output.properties.connection.connectionType == "IPsec"
    error_message = "The site-to-site connection should exist."
  }
  assert {
    condition     = lower(output.properties.bastion.ipConfigurations[0].properties.subnet.id) == lower(run.create.hub_virtual_networks.swedencentral.subnet_resource_ids.bastion)
    error_message = "Bastion should be in the hub's AzureBastionSubnet."
  }
  assert {
    condition     = lower(output.properties.private_dns_link.virtualNetwork.id) == lower(run.create.hub_virtual_networks.swedencentral.resource_id)
    error_message = "The private DNS zone should be linked to the hub."
  }
}

# Tags update both route tables (a PUT without their routes) while app1's route stays as it is; a second
# spoke is added; forced tunnelling through an appliance; custom DNS servers on the hub.
run "update" {
  variables {
    parent_id          = run.setup.parent_id
    tags               = { test = "update" }
    connection_secrets = { "swedencentral/office" = "it-${run.setup.suffix}-shared-key" }
    private_dns_zones  = { resource_group_name = "rg-mlz-hub-it-pdns-${run.setup.suffix}", zone_name_filter = "^privatelink\\.blob\\.core\\." }
    hub_virtual_networks = {
      swedencentral = {
        location                      = run.setup.location
        address_space                 = ["10.100.0.0/22"]
        is_primary                    = true
        name                          = "vnet-mlz-hub-it-${run.setup.suffix}"
        resource_group_name           = "rg-mlz-hub-it-${run.setup.suffix}"
        routing_supernet              = ["10.100.0.0/16"]
        spoke_address_prefixes        = { app1 = "10.100.8.0/24", app2 = "10.100.9.0/24" }
        virtual_network_dns_servers   = ["10.100.1.68"]
        gateway_subnet_address_prefix = "10.100.1.0/27"
        gateway_route_table_name      = "rt-vgw-mlz-hub-it-${run.setup.suffix}"
        firewall = {
          name                             = "afw-mlz-hub-it-${run.setup.suffix}"
          sku_tier                         = "Basic"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-mlz-hub-it-${run.setup.suffix}"
          management_public_ip_name        = "pip-afwm-mlz-hub-it-${run.setup.suffix}"
          route_table_name                 = "rt-afw-mlz-hub-it-${run.setup.suffix}"
          default_route                    = { next_hop_type = "VirtualAppliance", next_hop_ip_address = "10.100.2.4" }
          firewall_policy                  = { name = "afwp-mlz-hub-it-${run.setup.suffix}" }
        }
        nat_gateway = { name = "ng-mlz-hub-it-${run.setup.suffix}", public_ip_name = "pip-ng-mlz-hub-it-${run.setup.suffix}" }
        bastion     = { name = "bas-mlz-hub-it-${run.setup.suffix}", sku = "Basic", subnet_address_prefix = "10.100.0.128/26", public_ip_name = "pip-bas-mlz-hub-it-${run.setup.suffix}" }
        dns_resolver = {
          name                           = "dnspr-mlz-hub-it-${run.setup.suffix}"
          inbound_endpoint_name          = "in-mlz-hub-it-${run.setup.suffix}"
          outbound_endpoint_name         = "out-mlz-hub-it-${run.setup.suffix}"
          inbound_subnet_address_prefix  = "10.100.1.64/28"
          outbound_subnet_address_prefix = "10.100.1.80/28"
        }
        vpn_gateway = {
          name            = "vgw-mlz-hub-it-${run.setup.suffix}"
          public_ip_names = ["pip-vgw-mlz-hub-it-${run.setup.suffix}"]
          local_network_gateways = {
            office = { name = "lgw-mlz-hub-it-${run.setup.suffix}", gateway_ip_address = "203.0.113.10", address_prefixes = ["192.168.0.0/24"] }
          }
          connections = {
            office = { name = "con-mlz-hub-it-${run.setup.suffix}", local_network_gateway_key = "office" }
          }
        }
      }
    }
  }

  assert {
    condition     = output.hub_virtual_networks.swedencentral.firewall_resource_id == run.create.hub_virtual_networks.swedencentral.firewall_resource_id && output.hub_virtual_networks.swedencentral.vpn_gateway_resource_id == run.create.hub_virtual_networks.swedencentral.vpn_gateway_resource_id
    error_message = "The firewall and the gateway should be kept."
  }
}

run "read_after_update" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    resource_ids = {
      firewall_route_table = "Microsoft.Network/routeTables@2024-05-01|${run.create.hub_virtual_networks.swedencentral.firewall_route_table_resource_id}"
      gateway_route_table  = "Microsoft.Network/routeTables@2024-05-01|${run.create.hub_virtual_networks.swedencentral.gateway_route_table_resource_id}"
      firewall_subnet      = "Microsoft.Network/virtualNetworks/subnets@2024-07-01|${run.create.hub_virtual_networks.swedencentral.subnet_resource_ids.firewall}"
      hub                  = "Microsoft.Network/virtualNetworks@2024-07-01|${run.create.hub_virtual_networks.swedencentral.resource_id}"
    }
  }

  assert {
    condition     = jsonencode({ for route in output.properties.gateway_route_table.routes : route.name => route.properties.addressPrefix }) == jsonencode({ spoke-app1 = "10.100.8.0/24", spoke-app2 = "10.100.9.0/24" }) && output.tags.gateway_route_table.test == "update"
    error_message = "The route table update should keep the first spoke's route and add the second: ${jsonencode(output.properties.gateway_route_table.routes)}."
  }
  assert {
    condition     = jsonencode({ for route in output.properties.firewall_route_table.routes : route.name => [route.properties.addressPrefix, route.properties.nextHopType, try(route.properties.nextHopIpAddress, null)] }) == jsonencode({ default = ["0.0.0.0/0", "VirtualAppliance", "10.100.2.4"] }) && output.tags.firewall_route_table.test == "update"
    error_message = "The firewall subnet's default route should go to the appliance: ${jsonencode(output.properties.firewall_route_table.routes)}."
  }
  assert {
    condition     = jsonencode(output.properties.hub.dhcpOptions.dnsServers) == jsonencode(["10.100.1.68"])
    error_message = "The hub should use the custom DNS servers."
  }
  assert {
    condition     = lower(output.properties.firewall_subnet.routeTable.id) == lower(run.create.hub_virtual_networks.swedencentral.firewall_route_table_resource_id) && lower(output.properties.firewall_subnet.natGateway.id) == lower(run.create.hub_virtual_networks.swedencentral.nat_gateway_resource_id)
    error_message = "The virtual network's update should keep the firewall subnet's associations."
  }
}

# The first spoke's route removed, the default route back to the Internet, the custom DNS servers removed.
run "revert" {
  variables {
    parent_id          = run.setup.parent_id
    tags               = { test = "update" }
    connection_secrets = { "swedencentral/office" = "it-${run.setup.suffix}-shared-key" }
    private_dns_zones  = { resource_group_name = "rg-mlz-hub-it-pdns-${run.setup.suffix}", zone_name_filter = "^privatelink\\.blob\\.core\\." }
    hub_virtual_networks = {
      swedencentral = {
        location                      = run.setup.location
        address_space                 = ["10.100.0.0/22"]
        is_primary                    = true
        name                          = "vnet-mlz-hub-it-${run.setup.suffix}"
        resource_group_name           = "rg-mlz-hub-it-${run.setup.suffix}"
        routing_supernet              = ["10.100.0.0/16"]
        spoke_address_prefixes        = { app2 = "10.100.9.0/24" }
        gateway_subnet_address_prefix = "10.100.1.0/27"
        gateway_route_table_name      = "rt-vgw-mlz-hub-it-${run.setup.suffix}"
        firewall = {
          name                             = "afw-mlz-hub-it-${run.setup.suffix}"
          sku_tier                         = "Basic"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-mlz-hub-it-${run.setup.suffix}"
          management_public_ip_name        = "pip-afwm-mlz-hub-it-${run.setup.suffix}"
          route_table_name                 = "rt-afw-mlz-hub-it-${run.setup.suffix}"
          firewall_policy                  = { name = "afwp-mlz-hub-it-${run.setup.suffix}" }
        }
        nat_gateway = { name = "ng-mlz-hub-it-${run.setup.suffix}", public_ip_name = "pip-ng-mlz-hub-it-${run.setup.suffix}" }
        bastion     = { name = "bas-mlz-hub-it-${run.setup.suffix}", sku = "Basic", subnet_address_prefix = "10.100.0.128/26", public_ip_name = "pip-bas-mlz-hub-it-${run.setup.suffix}" }
        dns_resolver = {
          name                           = "dnspr-mlz-hub-it-${run.setup.suffix}"
          inbound_endpoint_name          = "in-mlz-hub-it-${run.setup.suffix}"
          outbound_endpoint_name         = "out-mlz-hub-it-${run.setup.suffix}"
          inbound_subnet_address_prefix  = "10.100.1.64/28"
          outbound_subnet_address_prefix = "10.100.1.80/28"
        }
        vpn_gateway = {
          name            = "vgw-mlz-hub-it-${run.setup.suffix}"
          public_ip_names = ["pip-vgw-mlz-hub-it-${run.setup.suffix}"]
          local_network_gateways = {
            office = { name = "lgw-mlz-hub-it-${run.setup.suffix}", gateway_ip_address = "203.0.113.10", address_prefixes = ["192.168.0.0/24"] }
          }
          connections = {
            office = { name = "con-mlz-hub-it-${run.setup.suffix}", local_network_gateway_key = "office" }
          }
        }
      }
    }
  }
}

run "read_after_revert" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    resource_ids = {
      firewall_route_table = "Microsoft.Network/routeTables@2024-05-01|${run.create.hub_virtual_networks.swedencentral.firewall_route_table_resource_id}"
      gateway_route_table  = "Microsoft.Network/routeTables@2024-05-01|${run.create.hub_virtual_networks.swedencentral.gateway_route_table_resource_id}"
      hub                  = "Microsoft.Network/virtualNetworks@2024-07-01|${run.create.hub_virtual_networks.swedencentral.resource_id}"
    }
  }

  assert {
    condition     = jsonencode({ for route in output.properties.gateway_route_table.routes : route.name => route.properties.addressPrefix }) == jsonencode({ spoke-app2 = "10.100.9.0/24" })
    error_message = "The removed spoke's route should be gone: ${jsonencode(output.properties.gateway_route_table.routes)}."
  }
  assert {
    condition     = jsonencode({ for route in output.properties.firewall_route_table.routes : route.name => [route.properties.addressPrefix, route.properties.nextHopType] }) == jsonencode({ default = ["0.0.0.0/0", "Internet"] })
    error_message = "The default route should be back to the Internet: ${jsonencode(output.properties.firewall_route_table.routes)}."
  }
  assert {
    condition     = length(try(output.properties.hub.dhcpOptions.dnsServers, [])) == 0
    error_message = "Removing the custom DNS servers should reach Azure: ${jsonencode(try(output.properties.hub.dhcpOptions, null))}."
  }
}

# The firewall's address and the gateway's BGP settings come from the resources' `output`, which azapi
# makes unknown in any plan that changes their body: equal values mean neither plans a change.
run "second_plan_is_clean" {
  command = plan

  variables {
    parent_id          = run.setup.parent_id
    tags               = { test = "update" }
    connection_secrets = { "swedencentral/office" = "it-${run.setup.suffix}-shared-key" }
    private_dns_zones  = { resource_group_name = "rg-mlz-hub-it-pdns-${run.setup.suffix}", zone_name_filter = "^privatelink\\.blob\\.core\\." }
    hub_virtual_networks = {
      swedencentral = {
        location                      = run.setup.location
        address_space                 = ["10.100.0.0/22"]
        is_primary                    = true
        name                          = "vnet-mlz-hub-it-${run.setup.suffix}"
        resource_group_name           = "rg-mlz-hub-it-${run.setup.suffix}"
        routing_supernet              = ["10.100.0.0/16"]
        spoke_address_prefixes        = { app2 = "10.100.9.0/24" }
        gateway_subnet_address_prefix = "10.100.1.0/27"
        gateway_route_table_name      = "rt-vgw-mlz-hub-it-${run.setup.suffix}"
        firewall = {
          name                             = "afw-mlz-hub-it-${run.setup.suffix}"
          sku_tier                         = "Basic"
          subnet_address_prefix            = "10.100.0.0/26"
          management_subnet_address_prefix = "10.100.0.64/26"
          public_ip_name                   = "pip-afw-mlz-hub-it-${run.setup.suffix}"
          management_public_ip_name        = "pip-afwm-mlz-hub-it-${run.setup.suffix}"
          route_table_name                 = "rt-afw-mlz-hub-it-${run.setup.suffix}"
          firewall_policy                  = { name = "afwp-mlz-hub-it-${run.setup.suffix}" }
        }
        nat_gateway = { name = "ng-mlz-hub-it-${run.setup.suffix}", public_ip_name = "pip-ng-mlz-hub-it-${run.setup.suffix}" }
        bastion     = { name = "bas-mlz-hub-it-${run.setup.suffix}", sku = "Basic", subnet_address_prefix = "10.100.0.128/26", public_ip_name = "pip-bas-mlz-hub-it-${run.setup.suffix}" }
        dns_resolver = {
          name                           = "dnspr-mlz-hub-it-${run.setup.suffix}"
          inbound_endpoint_name          = "in-mlz-hub-it-${run.setup.suffix}"
          outbound_endpoint_name         = "out-mlz-hub-it-${run.setup.suffix}"
          inbound_subnet_address_prefix  = "10.100.1.64/28"
          outbound_subnet_address_prefix = "10.100.1.80/28"
        }
        vpn_gateway = {
          name            = "vgw-mlz-hub-it-${run.setup.suffix}"
          public_ip_names = ["pip-vgw-mlz-hub-it-${run.setup.suffix}"]
          local_network_gateways = {
            office = { name = "lgw-mlz-hub-it-${run.setup.suffix}", gateway_ip_address = "203.0.113.10", address_prefixes = ["192.168.0.0/24"] }
          }
          connections = {
            office = { name = "con-mlz-hub-it-${run.setup.suffix}", local_network_gateway_key = "office" }
          }
        }
      }
    }
  }

  assert {
    condition     = output.hub_virtual_networks.swedencentral.firewall_private_ip_address == run.revert.hub_virtual_networks.swedencentral.firewall_private_ip_address && jsonencode(output.hub_virtual_networks.swedencentral.vpn_gateway_bgp_settings) == jsonencode(run.revert.hub_virtual_networks.swedencentral.vpn_gateway_bgp_settings)
    error_message = "The firewall and the gateway should plan no change after the last apply."
  }
}

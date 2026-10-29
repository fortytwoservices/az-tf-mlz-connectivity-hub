locals {
  primary_key     = one([for key, hub in var.hub_virtual_networks : key if hub.is_primary])
  subscription_id = provider::azapi::parse_resource_id("Microsoft.Resources/subscriptions", var.parent_id).subscription_id

  firewalls              = { for key, hub in var.hub_virtual_networks : key => hub.firewall if hub.firewall != null }
  nat_gateways           = { for key, hub in var.hub_virtual_networks : key => hub.nat_gateway if hub.nat_gateway != null }
  bastions               = { for key, hub in var.hub_virtual_networks : key => hub.bastion if hub.bastion != null }
  dns_resolvers          = { for key, hub in var.hub_virtual_networks : key => hub.dns_resolver if hub.dns_resolver != null }
  vpn_gateways           = { for key, hub in var.hub_virtual_networks : key => hub.vpn_gateway if hub.vpn_gateway != null }
  express_route_gateways = { for key, hub in var.hub_virtual_networks : key => hub.express_route_gateway if hub.express_route_gateway != null }
  # The GatewaySubnet's routes point at the hub's firewall, so only a hub with both gets the table.
  gateway_route_tables = { for key, hub in var.hub_virtual_networks : key => hub if hub.firewall != null && (hub.vpn_gateway != null || hub.express_route_gateway != null) }

  # Known before apply, so routes never wait on the firewall's `output` (unknown whenever its body changes):
  # Azure gives a VNet firewall its subnet's fifth address. The `connectivity` output checks Azure's.
  firewall_private_ip_addresses = { for key, firewall in local.firewalls : key => cidrhost(firewall.subnet_address_prefix, 4) }
  # The inbound endpoint's address is fixed, so the firewall's DNS proxy and the spokes can point at it
  # before the resolver exists. Azure would pick the subnet's fifth address too (sandbox, 2026-10-28).
  dns_resolver_inbound_ip_addresses = { for key, resolver in local.dns_resolvers : key => cidrhost(resolver.inbound_subnet_address_prefix, 4) }

  # Basic has no DNS proxy. With an existing policy the module cannot know, so spokes get the resolver.
  firewall_dns_proxy_enabled = {
    for key, hub in var.hub_virtual_networks : key => hub.firewall == null ? false : hub.firewall.firewall_policy_id != null ? false : coalesce(hub.firewall.firewall_policy.dns_proxy_enabled, hub.firewall.sku_tier != "Basic")
  }
  # The policy each firewall's module creates; null with an existing policy.
  firewall_policies = {
    for key, firewall in local.firewalls : key => firewall.firewall_policy_id != null ? null : {
      name                     = local.names[key].firewall_policy
      base_policy_id           = firewall.firewall_policy.base_policy_id
      threat_intelligence_mode = firewall.firewall_policy.threat_intelligence_mode
      dns = {
        proxy_enabled = local.firewall_dns_proxy_enabled[key]
        # The hub resolver's inbound address by default, else Azure DNS. A Basic policy takes no DNS
        # settings at all, custom servers included (az-tf-mlz-azure-firewall refuses them).
        servers = (
          firewall.sku_tier == "Basic" ? [] :
          firewall.firewall_policy.dns_servers != null ? firewall.firewall_policy.dns_servers :
          [for address in [lookup(local.dns_resolver_inbound_ip_addresses, key, null)] : address if address != null]
        )
      }
    }
  }
  dns_servers = {
    for key, hub in var.hub_virtual_networks : key => (
      local.firewall_dns_proxy_enabled[key] ? [local.firewall_private_ip_addresses[key]] :
      [for address in [lookup(local.dns_resolver_inbound_ip_addresses, key, null)] : address if address != null]
    )
  }
  # Azure offers no log categories on a resolver (az-tf-mlz-dns-resolver refuses `logs`).
  dns_resolver_diagnostic_settings = { for key, setting in var.diagnostic_settings : key => merge(setting, { logs = [] }) if length(setting.metrics) > 0 }
}

# The mesh: a peering from every hub to every other, and routes to the other regions' summaries.
locals {
  hub_peerings = var.mesh_peering_enabled ? {
    for pair in setproduct(sort(keys(var.hub_virtual_networks)), sort(keys(var.hub_virtual_networks))) : "${pair[0]}-to-${pair[1]}" => {
      local  = pair[0]
      remote = pair[1]
    } if pair[0] != pair[1]
  } : {}

  # By hub: each other firewalled hub's `routing_supernet` entries, keyed by a route name that stays put
  # when entries are added (letters, digits, periods, underscores and hyphens).
  remote_supernets = {
    for key in keys(var.hub_virtual_networks) : key => {
      for route in flatten([
        for remote, hub in var.hub_virtual_networks : [for prefix in hub.routing_supernet : { remote = remote, prefix = prefix }]
        if var.mesh_peering_enabled && remote != key && hub.firewall != null
      ]) : "hub-${route.remote}-${replace(route.prefix, "/", "_")}" => route
    }
  }

  # AzureFirewallSubnet: the default route (Internet unless forced tunnelling), and each other region
  # through its own firewall (Microsoft Learn, "Use Azure Firewall to route a multi-hub and spoke topology").
  firewall_routes = {
    for key, firewall in local.firewalls : key => merge(
      {
        for name, route in { default = firewall.default_route } : name => {
          name                       = name
          address_prefix             = "0.0.0.0/0"
          next_hop_type              = route.next_hop_type
          next_hop_in_ip_address     = route.next_hop_ip_address
        } if route.enabled
      },
      {
        for name, route in local.remote_supernets[key] : name => {
          name                   = name
          address_prefix         = route.prefix
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = local.firewall_private_ip_addresses[route.remote]
        }
      },
    )
  }
  # GatewaySubnet: every spoke of the region and every other region through the hub's firewall, so
  # on-premises traffic is inspected both ways. The exact spoke prefixes: the peerings' system routes are
  # more specific than a summary. No default route: Azure does not support one there.
  gateway_routes = {
    for key, hub in local.gateway_route_tables : key => merge(
      {
        for name, prefix in hub.spoke_address_prefixes : "spoke-${name}" => {
          name                   = "spoke-${name}"
          address_prefix         = prefix
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = local.firewall_private_ip_addresses[key]
        }
      },
      {
        for name, route in local.remote_supernets[key] : name => {
          name                   = name
          address_prefix         = route.prefix
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = local.firewall_private_ip_addresses[key]
        }
      },
    )
  }
  # What subscription vending puts on a spoke's route table, with `bgp_route_propagation_enabled = false`.
  spoke_default_routes = {
    for key, hub in var.hub_virtual_networks : key => hub.firewall == null ? null : {
      default = {
        name                   = "default"
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = local.firewall_private_ip_addresses[key]
      }
    }
  }
}

# The hub's subnets, from the components it has. Every subnet stays private (AVM's default): the hub holds
# no VMs, and private subnets do not apply to the managed subnets of these services (Microsoft Learn).
locals {
  hub_subnets = {
    for key, hub in var.hub_virtual_networks : key => merge(
      { for name, firewall in { firewall = hub.firewall } : name => {
        name                             = "AzureFirewallSubnet"
        address_prefix                   = firewall.subnet_address_prefix
        route_table                      = { id = module.firewall_route_table[key].resource_id }
        nat_gateway                      = hub.nat_gateway == null ? null : { id = module.nat_gateway[key].resource_id }
        retry                            = var.retry
        timeouts                         = var.timeouts
      } if firewall != null },
      # Azure associates its own route table here; a customer's can disrupt the firewall (Microsoft Learn,
      # "Azure Firewall Management NIC").
      { for name, prefix in { firewall_management = try(hub.firewall.management_subnet_address_prefix, null) } : name => {
        name                                      = "AzureFirewallManagementSubnet"
        address_prefix                            = prefix
        retry                                     = var.retry
        timeouts                                  = var.timeouts
      } if prefix != null },
      { for name, prefix in { gateway = hub.gateway_subnet_address_prefix } : name => {
        name                          = "GatewaySubnet"
        address_prefix                = prefix
        route_table                   = contains(keys(local.gateway_route_tables), key) ? { id = module.gateway_route_table[key].resource_id } : null
        retry                         = var.retry
        timeouts                      = var.timeouts
      } if prefix != null },
      { for name, bastion in { bastion = hub.bastion } : name => {
        name                           = "AzureBastionSubnet"
        address_prefix                 = bastion.subnet_address_prefix
        retry                          = var.retry
        timeouts                       = var.timeouts
      } if bastion != null },
      { for name, resolver in { dns_resolver_inbound = hub.dns_resolver } : name => {
        name                                         = resolver.inbound_subnet_name
        address_prefix                               = resolver.inbound_subnet_address_prefix
        delegations                                  = [{ name = "Microsoft.Network.dnsResolvers", service_delegation = { name = "Microsoft.Network/dnsResolvers" } }]
        retry                                        = var.retry
        timeouts                                     = var.timeouts
      } if resolver != null },
      { for name, resolver in { dns_resolver_outbound = hub.dns_resolver } : name => {
        name                                          = resolver.outbound_subnet_name
        address_prefix                                = resolver.outbound_subnet_address_prefix
        delegations                                   = [{ name = "Microsoft.Network.dnsResolvers", service_delegation = { name = "Microsoft.Network/dnsResolvers" } }]
        retry                                         = var.retry
        timeouts                                      = var.timeouts
      } if try(resolver.outbound_subnet_address_prefix, null) != null },
    )
  }

  # The VPN gateway's IP configurations in name order: instance 0, instance 1 when active-active, and the
  # point-to-site one of an active-active gateway.
  vpn_gateway_ip_configuration_counts = {
    for key, gateway in local.vpn_gateways : key => (gateway.active_active ? 2 : 1) + (gateway.active_active && gateway.point_to_site != null ? 1 : 0)
  }
}

# The private DNS zones: the primary hub's call creates them for its region, each other hub's call its
# regional zones; with a filter, only the primary's call runs.
locals {
  private_dns_zone_hubs = var.private_dns_zones == null ? {} : var.private_dns_zones.zone_name_filter != null ? { (local.primary_key) = var.hub_virtual_networks[local.primary_key] } : var.hub_virtual_networks
  private_dns_zone_ids = var.private_dns_zones == null ? null : {
    for id in flatten([for call in module.private_dns_zones : values(call.private_dns_zone_resource_ids)]) :
    provider::azapi::parse_resource_id("Microsoft.Network/privateDnsZones", id).name => id
  }
}

# Names: an explicit name wins, else the hub's naming template.
locals {
  naming_catalog_keys = {
    resource_group                 = "resource_group"
    virtual_network                = "virtual_network"
    firewall                       = "azure_firewall"
    firewall_policy                = "firewall_policy"
    firewall_public_ip             = "public_ip_address_firewall"
    firewall_management_public_ip  = "public_ip_address_firewall_management"
    firewall_route_table           = "route_table_firewall"
    nat_gateway                    = "nat_gateway"
    nat_gateway_public_ip          = "public_ip_address_nat_gateway"
    bastion                        = "bastion_host"
    bastion_public_ip              = "public_ip_address_bastion"
    dns_resolver                   = "dns_resolver"
    dns_resolver_inbound_endpoint  = "dns_resolver_inbound_endpoint"
    dns_resolver_outbound_endpoint = "dns_resolver_outbound_endpoint"
    vpn_gateway                    = "virtual_network_gateway"
    vpn_gateway_public_ip_1        = "public_ip_address_vpn_gateway_1"
    vpn_gateway_public_ip_2        = "public_ip_address_vpn_gateway_2"
    vpn_gateway_public_ip_3        = "public_ip_address_vpn_gateway_3"
    express_route_gateway          = "virtual_network_gateway_express_route_gateway"
    gateway_route_table            = "route_table_gateway"
    private_dns_resource_group     = "resource_group_private_dns"
  }
  template_names = {
    for key, hub in var.hub_virtual_networks : key => {
      for component, catalog_key in local.naming_catalog_keys : component => try(module.naming[key].names[catalog_key].name, null)
    }
  }

  # Only the components a hub has; each value null when neither an explicit name nor the template gives one.
  names = {
    for key, hub in var.hub_virtual_networks : key => merge(
      {
        resource_group  = try(coalesce(hub.resource_group_name, local.template_names[key].resource_group), null)
        virtual_network = try(coalesce(hub.name, local.template_names[key].virtual_network), null)
      },
      hub.firewall == null ? {} : {
        firewall             = try(coalesce(hub.firewall.name, local.template_names[key].firewall), null)
        firewall_public_ip   = try(coalesce(hub.firewall.public_ip_name, local.template_names[key].firewall_public_ip), null)
        firewall_route_table = try(coalesce(hub.firewall.route_table_name, local.template_names[key].firewall_route_table), null)
      },
      try(hub.firewall.firewall_policy_id, "") != null ? {} : { firewall_policy = try(coalesce(hub.firewall.firewall_policy.name, local.template_names[key].firewall_policy), null) },
      try(hub.firewall.management_subnet_address_prefix, null) == null ? {} : {
        firewall_management_public_ip = try(coalesce(hub.firewall.management_public_ip_name, local.template_names[key].firewall_management_public_ip), null)
      },
      hub.nat_gateway == null ? {} : {
        nat_gateway           = try(coalesce(hub.nat_gateway.name, local.template_names[key].nat_gateway), null)
        nat_gateway_public_ip = try(coalesce(hub.nat_gateway.public_ip_name, local.template_names[key].nat_gateway_public_ip), null)
      },
      hub.bastion == null ? {} : {
        bastion           = try(coalesce(hub.bastion.name, local.template_names[key].bastion), null)
        bastion_public_ip = try(coalesce(hub.bastion.public_ip_name, local.template_names[key].bastion_public_ip), null)
      },
      hub.dns_resolver == null ? {} : {
        dns_resolver                  = try(coalesce(hub.dns_resolver.name, local.template_names[key].dns_resolver), null)
        dns_resolver_inbound_endpoint = try(coalesce(hub.dns_resolver.inbound_endpoint_name, local.template_names[key].dns_resolver_inbound_endpoint), null)
      },
      try(hub.dns_resolver.outbound_subnet_address_prefix, null) == null ? {} : {
        dns_resolver_outbound_endpoint = try(coalesce(hub.dns_resolver.outbound_endpoint_name, local.template_names[key].dns_resolver_outbound_endpoint), null)
      },
      hub.vpn_gateway == null ? {} : merge(
        { vpn_gateway = try(coalesce(hub.vpn_gateway.name, local.template_names[key].vpn_gateway), null) },
        {
          for index in range(local.vpn_gateway_ip_configuration_counts[key]) : "vpn_gateway_public_ip_${index + 1}" => try(coalesce(
            try(hub.vpn_gateway.public_ip_names[index], null), local.template_names[key]["vpn_gateway_public_ip_${index + 1}"]
          ), null)
        },
      ),
      hub.express_route_gateway == null ? {} : { express_route_gateway = try(coalesce(hub.express_route_gateway.name, local.template_names[key].express_route_gateway), null) },
      contains(keys(local.gateway_route_tables), key) ? { gateway_route_table = try(coalesce(hub.gateway_route_table_name, local.template_names[key].gateway_route_table), null) } : {},
    )
  }
  private_dns_resource_group_name = var.private_dns_zones == null ? null : try(coalesce(var.private_dns_zones.resource_group_name, local.template_names[local.primary_key].private_dns_resource_group), null)

  missing_names = { for key, names in local.names : key => sort([for component, name in names : component if name == null]) }
  # Why the template gave no name, for the precondition's message.
  name_errors = {
    for key, components in local.missing_names : key => {
      for component in components : component => try(module.naming[key].names[local.naming_catalog_keys[component]].name_errors, [])
    }
  }
}

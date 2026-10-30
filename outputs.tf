output "connectivity" {
  description = <<DESCRIPTION
The connectivity contract shared with `az-tf-mlz-connectivity-vwan` (same keys; what does not apply to hub and spoke is null), for subscription vending, firewall rules and governance. It holds no secrets: publish it as JSON rather than reading this state.

- `topology` - `hub_and_spoke`.
- `connectivity_subscription_id` - The connectivity subscription's ID.
- `regions` - By `hub_virtual_networks` key: `is_primary`, `routing_supernet`, `hub_virtual_network_id` (spokes peer with it: the hub side allows gateway transit and forwarded traffic, the spoke side uses the remote gateways), `virtual_hub_id` and `vhub_route_table_ids` (null), `routing_intent_enabled` (false), `firewall_private_ip`, `firewall_policy_id`, `dns_servers` (the firewall's address when its DNS proxy is on, else the resolver's inbound address, else empty), `ipam_pool_id` (null), `ddos_protection_plan_id` (`ddos_protection_plan_id`) and `spoke_default_routes`: the routes for a spoke's route table, in `Azure/avm-ptn-alz-sub-vending/azure` v0.3.4's `routes` shape (`0.0.0.0/0` to the firewall; null without a firewall), applied with `bgp_route_propagation_enabled = false` so on-premises prefixes do not bypass the firewall.
- `base_firewall_policy_id` - The primary hub's firewall policy's parent, if any.
- `private_dns_zone_ids` - The private DNS zones' resource IDs by zone name, null without `private_dns_zones`.
- `private_dns_resource_group_id` - Their resource group's ID, null without `private_dns_zones`.
DESCRIPTION
  value = {
    topology                     = "hub_and_spoke"
    connectivity_subscription_id = local.subscription_id
    regions = {
      for key, hub in var.hub_virtual_networks : key => {
        is_primary              = hub.is_primary
        routing_supernet        = hub.routing_supernet
        hub_virtual_network_id  = module.hub_virtual_network[key].resource_id
        virtual_hub_id          = null
        vhub_route_table_ids    = null
        routing_intent_enabled  = false
        firewall_private_ip     = lookup(local.firewall_private_ip_addresses, key, null)
        firewall_policy_id      = try(module.firewall[key].firewall_policy_resource_id, null)
        dns_servers             = local.dns_servers[key]
        ipam_pool_id            = null
        ddos_protection_plan_id = var.ddos_protection_plan_id
        spoke_default_routes    = local.spoke_default_routes[key]
      }
    }
    base_firewall_policy_id       = try(local.firewall_policies[local.primary_key].base_policy_id, null)
    private_dns_zone_ids          = local.private_dns_zone_ids
    private_dns_resource_group_id = one(azapi_resource.private_dns_resource_group[*].id)
  }

  # The routes and the contract use the subnet's fifth address; a stop and start of the firewall can move
  # its address (Microsoft Learn, "Azure Firewall Management NIC"), which this catches.
  precondition {
    condition     = alltrue([for key, address in local.firewall_private_ip_addresses : module.firewall[key].private_ip_address == address])
    error_message = "A firewall's private IP address in Azure is not its subnet's fifth address, which the routes use: ${jsonencode({ for key, address in local.firewall_private_ip_addresses : key => { expected = address, azure = module.firewall[key].private_ip_address } })}."
  }
}

output "hub_virtual_networks" {
  description = <<DESCRIPTION
What each hub's resources are, by `hub_virtual_networks` key (null where a hub has none):

- `resource_group_id`, `resource_id`, `name` (the hub virtual network), `subnet_resource_ids` (by `firewall`, `firewall_management`, `gateway`, `bastion`, `dns_resolver_inbound`, `dns_resolver_outbound`), `peering_resource_ids` (by remote hub key).
- `firewall_resource_id`, `firewall_private_ip_address` (from Azure), `firewall_public_ip_addresses`, `firewall_policy_resource_id`, `firewall_route_table_resource_id`, `nat_gateway_resource_id`, `nat_gateway_public_ip_addresses`.
- `bastion_resource_id`, `dns_resolver_resource_id`, `dns_resolver_inbound_ip_address`, `dns_resolver_outbound_endpoint_resource_id` (for the caller's forwarding rulesets).
- `vpn_gateway_resource_id`, `vpn_gateway_public_ip_addresses`, `vpn_gateway_bgp_settings` (ASN and peering addresses, for on-premises devices), `vpn_gateway_connection_resource_ids`, `vpn_gateway_local_network_gateway_resource_ids`, `express_route_gateway_resource_id`, `express_route_gateway_connection_resource_ids`, `gateway_route_table_resource_id`.
DESCRIPTION
  value = {
    for key, hub in var.hub_virtual_networks : key => {
      resource_group_id                              = azapi_resource.resource_group[key].id
      resource_id                                    = module.hub_virtual_network[key].resource_id
      name                                           = module.hub_virtual_network[key].name
      subnet_resource_ids                            = { for name, subnet in module.hub_virtual_network[key].subnets : name => subnet.resource_id }
      peering_resource_ids                           = { for peering_key, peering in local.hub_peerings : peering.remote => module.hub_peering[peering_key].resource_id if peering.local == key }
      firewall_resource_id                           = try(module.firewall[key].resource_id, null)
      firewall_private_ip_address                    = try(module.firewall[key].private_ip_address, null)
      firewall_public_ip_addresses                   = try(module.firewall[key].public_ip_addresses, null)
      firewall_policy_resource_id                    = try(module.firewall[key].firewall_policy_resource_id, null)
      firewall_route_table_resource_id               = try(azapi_resource.route_table["${key}/firewall"].id, null)
      nat_gateway_resource_id                        = try(module.nat_gateway[key].resource_id, null)
      nat_gateway_public_ip_addresses                = try(module.nat_gateway[key].public_ip_addresses, null)
      bastion_resource_id                            = try(module.bastion[key].resource_id, null)
      dns_resolver_resource_id                       = try(module.dns_resolver[key].resource_id, null)
      dns_resolver_inbound_ip_address                = lookup(local.dns_resolver_inbound_ip_addresses, key, null)
      dns_resolver_outbound_endpoint_resource_id     = try(module.dns_resolver[key].outbound_endpoint_resource_ids.outbound, null)
      vpn_gateway_resource_id                        = try(module.vpn_gateway[key].resource_id, null)
      vpn_gateway_public_ip_addresses                = try(module.vpn_gateway[key].public_ip_addresses, null)
      vpn_gateway_bgp_settings                       = try(module.vpn_gateway[key].bgp_settings, null)
      vpn_gateway_connection_resource_ids            = try(module.vpn_gateway[key].connection_resource_ids, null)
      vpn_gateway_local_network_gateway_resource_ids = try(module.vpn_gateway[key].local_network_gateway_resource_ids, null)
      express_route_gateway_resource_id              = try(module.express_route_gateway[key].resource_id, null)
      express_route_gateway_connection_resource_ids  = try(module.express_route_gateway[key].connection_resource_ids, null)
      gateway_route_table_resource_id                = try(azapi_resource.route_table["${key}/gateway"].id, null)
    }
  }
}

output "name" {
  description = "Name of the primary hub's virtual network."
  value       = module.hub_virtual_network[local.primary_key].name
}

output "resource_id" {
  description = "Resource ID of the primary hub's virtual network."
  value       = module.hub_virtual_network[local.primary_key].resource_id
}

# Route tables from subscription vending's submodule (AzAPI, each route its own child resource), the same
# code that gives the spokes theirs. Both keep gateway route propagation on: the firewall learns
# on-premises routes, and GatewaySubnet must not turn it off (Microsoft Learn).
module "firewall_route_table" {
  source   = "Azure/avm-ptn-alz-sub-vending/azure//modules/route-table"
  version  = "0.3.4"
  for_each = local.firewalls

  name                          = local.names[each.key].firewall_route_table
  parent_id                     = azapi_resource.resource_group[each.key].id
  location                      = var.hub_virtual_networks[each.key].location
  bgp_route_propagation_enabled = true
  routes                        = local.firewall_routes[each.key]
  tags                          = var.tags
  resource_types                = var.resource_types.network_route_tables
  retry                         = var.retry
  timeouts                      = var.timeouts
}

module "gateway_route_table" {
  source   = "Azure/avm-ptn-alz-sub-vending/azure//modules/route-table"
  version  = "0.3.4"
  for_each = local.gateway_route_tables

  name                          = local.names[each.key].gateway_route_table
  parent_id                     = azapi_resource.resource_group[each.key].id
  location                      = each.value.location
  bgp_route_propagation_enabled = true
  routes                        = local.gateway_routes[each.key]
  tags                          = var.tags
  resource_types                = var.resource_types.network_route_tables
  retry                         = var.retry
  timeouts                      = var.timeouts
}

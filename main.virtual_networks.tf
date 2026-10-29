module "hub_virtual_network" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm" # AzAPI only, despite the suffix
  version  = "0.22.3"
  for_each = var.hub_virtual_networks

  enable_telemetry = false
  name             = local.names[each.key].virtual_network
  parent_id        = azapi_resource.resource_group[each.key].id
  location         = each.value.location
  address_space    = toset(each.value.address_space)
  # Always sent, so removing the servers reaches Azure (an empty list is Azure-provided DNS).
  dns_servers          = { dns_servers = coalesce(each.value.virtual_network_dns_servers, []) }
  ddos_protection_plan = var.ddos_protection_plan_id == null ? null : { id = var.ddos_protection_plan_id, enable = true }
  subnets              = local.hub_subnets[each.key]
  tags                 = var.tags
  ignore_body_changes  = var.ignore_body_changes.network_virtual_networks
  retry                = var.retry
  timeouts             = var.timeouts
}

# Its own calls, so a hub's virtual network does not wait for the other hubs'. Spoke traffic crosses the
# peering after a firewall forwards it; each hub keeps its own gateways.
module "hub_peering" {
  source   = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  version  = "0.22.3"
  for_each = local.hub_peerings

  name                         = "peer-${local.names[each.value.remote].virtual_network}"
  parent_id                    = module.hub_virtual_network[each.value.local].resource_id
  remote_virtual_network_id    = module.hub_virtual_network[each.value.remote].resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  ignore_body_changes          = var.ignore_body_changes.network_virtual_networks.virtual_networks_virtual_network_peerings
  retry                        = var.retry
  timeouts                     = var.timeouts
}

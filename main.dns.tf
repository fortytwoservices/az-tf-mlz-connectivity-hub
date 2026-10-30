module "dns_resolver" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-dns-resolver.git?ref=v0.1.0"
  for_each = local.dns_resolvers

  name               = local.names[each.key].dns_resolver
  parent_id          = azapi_resource.resource_group[each.key].id
  location           = var.hub_virtual_networks[each.key].location
  virtual_network_id = module.hub_virtual_network[each.key].resource_id
  inbound_endpoints = {
    inbound = {
      name               = local.names[each.key].dns_resolver_inbound_endpoint
      subnet_id          = module.hub_virtual_network[each.key].subnets["dns_resolver_inbound"].resource_id
      private_ip_address = local.dns_resolver_inbound_ip_addresses[each.key]
    }
  }
  outbound_endpoints = {
    for name, prefix in { outbound = each.value.outbound_subnet_address_prefix } : name => {
      name                         = local.names[each.key].dns_resolver_outbound_endpoint
      subnet_id                    = module.hub_virtual_network[each.key].subnets["dns_resolver_outbound"].resource_id
    } if prefix != null
  }
  diagnostic_settings = local.dns_resolver_diagnostic_settings
  tags                = var.tags
  resource_types      = var.resource_types.network_dns_resolvers
  ignore_body_changes = var.ignore_body_changes.network_dns_resolvers
  retry               = var.retry
  timeouts            = var.timeouts
}

# Linked to every hub virtual network, where the resolvers resolve them for the spokes and on-premises.
module "private_dns_zones" {
  source   = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm" # AzAPI only, despite the suffix
  version  = "0.23.2"
  for_each = local.private_dns_zone_hubs

  enable_telemetry = false
  location         = each.value.location
  parent_id        = azapi_resource.private_dns_resource_group[0].id
  private_link_private_dns_zones_regex_filter = (
    each.key == local.primary_key ?
    { enabled = var.private_dns_zones.zone_name_filter != null, regex_filter = coalesce(var.private_dns_zones.zone_name_filter, "{regionName}|{regionCode}") } :
    { enabled = true, regex_filter = "{regionName}|{regionCode}" }
  )
  private_link_excluded_zones               = var.private_dns_zones.excluded_zones
  private_link_private_dns_zones_additional = each.key == local.primary_key ? { for key, zone in var.private_dns_zones.additional_zones : key => { zone_name = zone } } : {}
  virtual_network_link_default_virtual_networks = {
    for key in keys(var.hub_virtual_networks) : key => { virtual_network_resource_id = module.hub_virtual_network[key].resource_id }
  }
  tags = var.tags
  timeouts = {
    dns_zones  = local.avm_timeouts
    vnet_links = local.avm_timeouts
  }
}

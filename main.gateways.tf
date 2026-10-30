module "vpn_gateway" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-virtual-network-gateway.git?ref=v0.1.0"
  for_each = local.vpn_gateways

  name           = local.names[each.key].vpn_gateway
  parent_id      = azapi_resource.resource_group[each.key].id
  location       = var.hub_virtual_networks[each.key].location
  subnet_id      = module.hub_virtual_network[each.key].subnets["gateway"].resource_id
  gateway_type   = "Vpn"
  sku            = each.value.sku
  vpn_generation = each.value.vpn_generation
  active_active  = each.value.active_active
  bgp            = each.value.bgp
  point_to_site  = each.value.point_to_site
  # Instance 0 first: Azure does not change a gateway's first public IP address, so its name stays put.
  ip_configurations = {
    for index in range(local.vpn_gateway_ip_configuration_counts[each.key]) : "ipconfig${index + 1}" => {
      public_ip = { name = local.names[each.key]["vpn_gateway_public_ip_${index + 1}"] }
    }
  }
  local_network_gateways = each.value.local_network_gateways
  connections            = each.value.connections
  connection_secrets     = { for name in keys(each.value.connections) : name => var.connection_secrets["${each.key}/${name}"] if contains(keys(var.connection_secrets), "${each.key}/${name}") }
  diagnostic_settings    = var.diagnostic_settings
  tags                   = var.tags
  resource_types         = var.resource_types.network_virtual_network_gateways
  ignore_body_changes    = var.ignore_body_changes.network_virtual_network_gateways
  retry                  = var.retry
  timeouts               = var.timeouts

  # After the firewall, as Bastion (main.bastions.tf).
  depends_on = [module.firewall]
}

# Azure assigns and manages an ExpressRoute gateway's public IP address.
module "express_route_gateway" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-virtual-network-gateway.git?ref=v0.1.0"
  for_each = local.express_route_gateways

  name                      = local.names[each.key].express_route_gateway
  parent_id                 = azapi_resource.resource_group[each.key].id
  location                  = var.hub_virtual_networks[each.key].location
  subnet_id                 = module.hub_virtual_network[each.key].subnets["gateway"].resource_id
  gateway_type              = "ExpressRoute"
  sku                       = each.value.sku
  express_route_scale_units = each.value.express_route_scale_units
  connections               = { for key, connection in each.value.connections : key => merge(connection, { type = "ExpressRoute" }) }
  connection_secrets        = { for name in keys(each.value.connections) : name => var.connection_secrets["${each.key}/${name}"] if contains(keys(var.connection_secrets), "${each.key}/${name}") }
  diagnostic_settings       = var.diagnostic_settings
  tags                      = var.tags
  resource_types            = var.resource_types.network_virtual_network_gateways
  ignore_body_changes       = var.ignore_body_changes.network_virtual_network_gateways
  retry                     = var.retry
  timeouts                  = var.timeouts

  # After the firewall, as Bastion (main.bastions.tf).
  depends_on = [module.firewall]
}

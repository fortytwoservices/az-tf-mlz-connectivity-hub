# The routes are in the route table's body, not child resources: Azure replaces a route table's routes with
# the ones a PUT carries, so a table written without them (a tag change) deleted every route (integration
# test, 2026-10-29, with sub-vending's route-table module, which writes them as children). Both tables keep
# gateway route propagation on: the firewall learns on-premises routes, and GatewaySubnet must not turn
# it off (Microsoft Learn).
resource "azapi_resource" "route_table" {
  for_each = local.route_tables

  type      = var.resource_types.network_route_tables
  name      = each.value.name
  parent_id = azapi_resource.resource_group[each.value.hub].id
  location  = var.hub_virtual_networks[each.value.hub].location
  body = {
    properties = {
      disableBgpRoutePropagation = false
      routes = [for name in sort(keys(each.value.routes)) : {
        name = name
        properties = {
          addressPrefix    = each.value.routes[name].address_prefix
          nextHopType      = each.value.routes[name].next_hop_type
          nextHopIpAddress = each.value.routes[name].next_hop_in_ip_address
        }
      }]
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_route_tables) > 0 ? var.ignore_body_changes.network_route_tables : null
  # Compared by name, whatever order Azure returns them in; a removed route is a shorter list.
  list_unique_id_property = { "properties.routes" = "name" }
  response_export_values  = []
  retry                   = var.retry
  tags                    = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # Azure refuses to delete a table a subnet uses (`InUseRouteTableCannotBeDeleted`; az-tf-mlz-route-table's
  # integration test), so a renamed table is created first and the subnet moves to it before the old one
  # goes. As az-tf-mlz-route-table v0.1.0 does, which this resource moves into later.
  lifecycle {
    create_before_destroy = true
  }
}

# One resource group per region's hub (Cloud Adoption Framework, "Traditional Azure networking topology").
resource "azapi_resource" "resource_group" {
  for_each = var.hub_virtual_networks

  type                   = var.resource_types.resources_resource_groups
  name                   = local.names[each.key].resource_group
  parent_id              = var.parent_id
  location               = each.value.location
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) > 0 ? var.ignore_body_changes.resources_resource_groups : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.missing_names[each.key]) == 0
      error_message = "`hub_virtual_networks[\"${each.key}\"]` has no name for: ${join(", ", local.missing_names[each.key])}. Set them, or set `naming`${var.naming == null ? "" : ", whose template made none (${jsonencode(local.name_errors[each.key])})"}."
    }
    precondition {
      condition     = length(distinct([for names in local.names : lower(coalesce(names.resource_group, "-"))])) == length(var.hub_virtual_networks)
      error_message = "Each hub needs a resource group of its own: two hubs have the same `resource_group_name`."
    }
    # The hub peerings are named after the remote hub's virtual network.
    precondition {
      condition     = length(distinct([for names in local.names : lower(coalesce(names.virtual_network, "-"))])) == length(var.hub_virtual_networks)
      error_message = "Each hub virtual network needs a name of its own: two hubs have the same `name`."
    }
  }
}

resource "azapi_resource" "private_dns_resource_group" {
  count = var.private_dns_zones == null ? 0 : 1

  type                   = var.resource_types.resources_resource_groups
  name                   = local.private_dns_resource_group_name
  parent_id              = var.parent_id
  location               = var.hub_virtual_networks[local.primary_key].location
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) > 0 ? var.ignore_body_changes.resources_resource_groups : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    precondition {
      condition     = local.private_dns_resource_group_name != null
      error_message = "The private DNS zones' resource group has no name: set `private_dns_zones.resource_group_name`, or set `naming`${var.naming == null ? "" : ", whose template made none (${jsonencode(try(module.naming[local.primary_key].names.resource_group_private_dns.name_errors, []))})"}."
    }
    precondition {
      condition     = !contains([for names in local.names : lower(coalesce(names.resource_group, "-"))], lower(coalesce(local.private_dns_resource_group_name, "-")))
      error_message = "The private DNS zones need a resource group of their own: `private_dns_zones.resource_group_name` is a hub's."
    }
  }
}

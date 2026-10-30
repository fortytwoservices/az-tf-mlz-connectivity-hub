# Region short names for the `region` token (cached data: no Azure call).
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm" # AzAPI only, despite the suffix
  version = "0.13.0"
  count   = var.naming == null ? 0 : 1

  enable_telemetry = false
  location         = var.hub_virtual_networks[local.primary_key].location
}

module "naming" {
  source   = "Azure/avm-utl-naming/azure"
  version  = "0.2.0"
  for_each = var.naming == null ? {} : var.hub_virtual_networks

  instance = var.naming.instance
  naming_template_variables = merge(var.naming.variables, {
    region = try(module.regions[0].regions_by_name[each.value.location].geo_code, each.value.location)
  })
  naming_templates = { name = var.naming.template }
  slug_overrides   = var.naming.slug_overrides
  # Lets NAT gateway names have hyphens, and adds keys for the resources a hub has several of (public IP
  # addresses by role, two route tables, the private DNS zones' resource group).
  custom_override_file = coalesce(var.naming.custom_override_file, "${path.module}/naming-overrides.json")
}

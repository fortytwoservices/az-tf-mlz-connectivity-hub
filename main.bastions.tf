module "bastion" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-bastion.git?ref=v0.1.0"
  for_each = local.bastions

  name                   = local.names[each.key].bastion
  parent_id              = azapi_resource.resource_group[each.key].id
  location               = var.hub_virtual_networks[each.key].location
  sku                    = each.value.sku
  zones                  = each.value.zones
  scale_units            = each.value.scale_units
  copy_paste_enabled     = each.value.copy_paste_enabled
  file_copy_enabled      = each.value.file_copy_enabled
  ip_connect_enabled     = each.value.ip_connect_enabled
  kerberos_enabled       = each.value.kerberos_enabled
  shareable_link_enabled = each.value.shareable_link_enabled
  tunneling_enabled      = each.value.tunneling_enabled
  ip_configuration = {
    subnet_id = module.hub_virtual_network[each.key].subnets["bastion"].resource_id
    public_ip = { name = local.names[each.key].bastion_public_ip }
  }
  diagnostic_settings = var.diagnostic_settings
  tags                = var.tags
  resource_types      = var.resource_types.network_bastion_hosts
  ignore_body_changes = var.ignore_body_changes.network_bastion_hosts
  retry               = var.retry
  timeouts            = var.timeouts

  # After the firewall: created at the same time in one virtual network, Azure failed the firewall twice
  # out of two (InternalServerError; sandbox, 2026-10-29). The module reads nothing from Azure while it
  # has no role assignments, so this only orders the writes; revisit if role assignments come in.
  depends_on = [module.firewall]
}

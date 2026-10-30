module "firewall" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-azure-firewall.git?ref=v0.1.3"
  for_each = local.firewalls

  name      = local.names[each.key].firewall
  parent_id = azapi_resource.resource_group[each.key].id
  location  = var.hub_virtual_networks[each.key].location
  sku_tier  = each.value.sku_tier
  zones     = each.value.zones
  virtual_network = {
    subnet_id = module.hub_virtual_network[each.key].subnets["firewall"].resource_id
    public_ip = { name = local.names[each.key].firewall_public_ip }
    management = each.value.management_subnet_address_prefix == null ? null : {
      subnet_id = module.hub_virtual_network[each.key].subnets["firewall_management"].resource_id
      public_ip = { name = local.names[each.key].firewall_management_public_ip }
    }
  }
  firewall_policy_id  = each.value.firewall_policy_id
  firewall_policy     = local.firewall_policies[each.key]
  diagnostic_settings = var.diagnostic_settings
  tags                = var.tags
  resource_types      = var.resource_types.network_azure_firewalls
  ignore_body_changes = var.ignore_body_changes.network_azure_firewalls
  retry               = var.retry
  timeouts            = var.timeouts

  # After every write to the hub virtual networks (and through them the route tables and NAT gateways): a
  # policy update makes Azure (the NFV resource provider) push the policy to its firewall, and that push
  # failed, unretried, while a virtual network update held the firewall's subnet in `Updating`
  # (`ReferencedResourceNotProvisioned`), leaving the firewall faulted and the policy update failed
  # (integration test, 2026-10-29). The module reads nothing from Azure while it has no role assignments,
  # so this only orders the writes; revisit if role assignments come in.
  depends_on = [module.hub_virtual_network, module.hub_peering]
}

# On AzureFirewallSubnet, the firewall's outbound path (Microsoft Learn, "Scale SNAT ports with Azure NAT
# Gateway"); the subnet sets its own `natGateway.id`.
module "nat_gateway" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-nat-gateway.git?ref=v0.1.0"
  for_each = local.nat_gateways

  name                    = local.names[each.key].nat_gateway
  parent_id               = azapi_resource.resource_group[each.key].id
  location                = var.hub_virtual_networks[each.key].location
  sku_name                = each.value.sku_name
  zones                   = each.value.zones
  idle_timeout_in_minutes = each.value.idle_timeout_in_minutes
  public_ips              = { ipv4 = { name = local.names[each.key].nat_gateway_public_ip } }
  tags                    = var.tags
  resource_types          = var.resource_types.network_nat_gateways
  ignore_body_changes     = var.ignore_body_changes.network_nat_gateways
  retry                   = var.retry
  timeouts                = var.timeouts
}

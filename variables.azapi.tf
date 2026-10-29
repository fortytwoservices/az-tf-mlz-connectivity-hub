variable "ignore_body_changes" {
  type = object({
    resources_resource_groups = optional(list(string), [])

    network_virtual_networks = optional(object({
      virtual_networks = optional(list(string), [])
      virtual_networks_subnets = optional(object({
        virtual_networks_subnets = optional(list(string), [])
      }), {})
      virtual_networks_virtual_network_peerings = optional(object({
        virtual_networks_virtual_network_peerings = optional(list(string), [])
      }), {})
    }), {})
    network_azure_firewalls = optional(object({
      network_azure_firewalls        = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
      network_firewall_policies = optional(object({
        network_firewall_policies      = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
      }), {})
      network_firewall_policies_rule_collection_groups = optional(object({
        network_firewall_policies_rule_collection_groups = optional(list(string), [])
      }), {})
      network_ip_groups = optional(object({
        network_ip_groups              = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
      }), {})
      network_virtual_hubs_routing_intent = optional(object({
        network_virtual_hubs_routing_intent = optional(list(string), [])
      }), {})
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
        insights_diagnostic_settings   = optional(list(string), [])
      }), {})
    }), {})
    network_nat_gateways = optional(object({
      network_nat_gateways           = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
        insights_diagnostic_settings   = optional(list(string), [])
      }), {})
      network_public_ip_prefixes = optional(object({
        network_public_ip_prefixes     = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
        insights_diagnostic_settings   = optional(list(string), [])
      }), {})
    }), {})
    network_bastion_hosts = optional(object({
      network_bastion_hosts          = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
        insights_diagnostic_settings   = optional(list(string), [])
      }), {})
    }), {})
    network_dns_resolvers = optional(object({
      network_dns_resolvers          = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
      network_dns_resolvers_inbound_endpoints = optional(object({
        network_dns_resolvers_inbound_endpoints = optional(list(string), [])
      }), {})
      network_dns_resolvers_outbound_endpoints = optional(object({
        network_dns_resolvers_outbound_endpoints = optional(list(string), [])
      }), {})
    }), {})
    network_virtual_network_gateways = optional(object({
      network_virtual_network_gateways = optional(list(string), [])
      authorization_locks              = optional(list(string), [])
      authorization_role_assignments   = optional(list(string), [])
      insights_diagnostic_settings     = optional(list(string), [])
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
        insights_diagnostic_settings   = optional(list(string), [])
      }), {})
      network_local_network_gateways = optional(object({
        network_local_network_gateways = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
      }), {})
      network_connections = optional(object({
        network_connections            = optional(list(string), [])
        authorization_locks            = optional(list(string), [])
        authorization_role_assignments = optional(list(string), [])
        insights_diagnostic_settings   = optional(list(string), [])
      }), {})
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.dhcpOptions`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list. Changes take effect only after an apply, because the value is held in provider-private state.

- `resources_resource_groups` - Ignored body paths for the resource groups.
- `network_virtual_networks` - Slot for the hub virtual networks, `Azure/avm-res-network-virtualnetwork/azurerm`'s `ignore_body_changes`; the hub peerings use its `virtual_networks_virtual_network_peerings` slot.
- `network_azure_firewalls` - Slot for `az-tf-mlz-azure-firewall`, shaped like its `ignore_body_changes`.
- `network_nat_gateways` - Slot for `az-tf-mlz-nat-gateway`, shaped like its `ignore_body_changes`.
- `network_bastion_hosts` - Slot for `az-tf-mlz-bastion`, shaped like its `ignore_body_changes`.
- `network_dns_resolvers` - Slot for `az-tf-mlz-dns-resolver`, shaped like its `ignore_body_changes` (without the rulesets, which this module does not create).
- `network_virtual_network_gateways` - Slot for `az-tf-mlz-virtual-network-gateway` (the VPN and the ExpressRoute gateways), shaped like its `ignore_body_changes`.

The route tables (`Azure/avm-ptn-alz-sub-vending/azure//modules/route-table`) and the private DNS zones (`Azure/avm-ptn-network-private-link-private-dns-zones/azurerm`) take no ignored paths.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    resources_resource_groups = optional(string, "Microsoft.Resources/resourceGroups@2025-04-01")

    network_route_tables = optional(object({
      this  = optional(string)
      route = optional(string)
    }), {})
    network_azure_firewalls = optional(object({
      network_azure_firewalls        = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
      network_firewall_policies = optional(object({
        network_firewall_policies      = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
      }), {})
      network_firewall_policies_rule_collection_groups = optional(object({
        network_firewall_policies_rule_collection_groups = optional(string)
      }), {})
      network_ip_groups = optional(object({
        network_ip_groups              = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
      }), {})
      network_virtual_hubs_routing_intent = optional(object({
        network_virtual_hubs_routing_intent = optional(string)
      }), {})
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
        insights_diagnostic_settings   = optional(string)
      }), {})
    }), {})
    network_nat_gateways = optional(object({
      network_nat_gateways           = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
        insights_diagnostic_settings   = optional(string)
      }), {})
      network_public_ip_prefixes = optional(object({
        network_public_ip_prefixes     = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
        insights_diagnostic_settings   = optional(string)
      }), {})
    }), {})
    network_bastion_hosts = optional(object({
      network_bastion_hosts          = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
        insights_diagnostic_settings   = optional(string)
      }), {})
    }), {})
    network_dns_resolvers = optional(object({
      network_dns_resolvers          = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
      network_dns_resolvers_inbound_endpoints = optional(object({
        network_dns_resolvers_inbound_endpoints = optional(string)
      }), {})
      network_dns_resolvers_outbound_endpoints = optional(object({
        network_dns_resolvers_outbound_endpoints = optional(string)
      }), {})
    }), {})
    network_virtual_network_gateways = optional(object({
      network_virtual_network_gateways = optional(string)
      authorization_locks              = optional(string)
      authorization_role_assignments   = optional(string)
      insights_diagnostic_settings     = optional(string)
      network_public_ip_addresses = optional(object({
        network_public_ip_addresses    = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
        insights_diagnostic_settings   = optional(string)
      }), {})
      network_local_network_gateways = optional(object({
        network_local_network_gateways = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
      }), {})
      network_connections = optional(object({
        network_connections            = optional(string)
        authorization_locks            = optional(string)
        authorization_role_assignments = optional(string)
        insights_diagnostic_settings   = optional(string)
      }), {})
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module and the modules it calls. Each key defaults to a tested value; supply only the keys you want to override.

- `resources_resource_groups` - The resource groups.
- `network_route_tables` - Slot for `Azure/avm-ptn-alz-sub-vending/azure//modules/route-table`: `this` (the route tables) and `route` (their routes). Defaults live in that module.
- `network_azure_firewalls` - Slot for `az-tf-mlz-azure-firewall`, shaped like its `resource_types`. Defaults live in that module.
- `network_nat_gateways` - Slot for `az-tf-mlz-nat-gateway`, shaped like its `resource_types`. Defaults live in that module.
- `network_bastion_hosts` - Slot for `az-tf-mlz-bastion`, shaped like its `resource_types`. Defaults live in that module.
- `network_dns_resolvers` - Slot for `az-tf-mlz-dns-resolver`, shaped like its `resource_types` (without the rulesets). Defaults live in that module.
- `network_virtual_network_gateways` - Slot for `az-tf-mlz-virtual-network-gateway` (the VPN and the ExpressRoute gateways), shaped like its `resource_types`. Defaults live in that module.

The hub virtual networks and their peerings use `Azure/avm-res-network-virtualnetwork/azurerm` v0.22.3's fixed `2024-07-01`; the private DNS zones use `Azure/avm-ptn-network-private-link-private-dns-zones/azurerm` v0.23.2's own.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["AnotherOperationInProgress", "ReferencedResourceNotProvisioned", "CannotDeleteResource"])
    interval_seconds     = optional(number, 30)
    max_interval_seconds = optional(number, 300)
  })
  default     = {}
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module and the modules it calls. The defaults retry what those modules retry by default: `AnotherOperationInProgress` (parallel writes to a virtual network, a route table, a firewall policy or a gateway), `ReferencedResourceNotProvisioned` (a subnet or peering written while its virtual network is still updating) and `CannotDeleteResource` (a resolver deleted right after its endpoints); any field can be overridden.

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds. Defaults to `30`.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds. Defaults to `300`.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string, "90m")
    read   = optional(string, "5m")
    update = optional(string, "90m")
    delete = optional(string, "90m")
  })
  default     = {}
  description = <<DESCRIPTION
Per-operation timeouts applied to every `azapi` resource managed by the module and the modules it calls. Each value is a Go duration string (e.g. `30m`, `1h`). A VPN gateway write takes up to 45 minutes by Microsoft Learn (62 were seen in the sandbox), a firewall's tens of minutes, so writes default to 90 minutes; any field can be overridden.

- `create` - (Optional) Timeout for create operations. Defaults to `90m`.
- `read`   - (Optional) Timeout for read operations. Defaults to `5m`.
- `update` - (Optional) Timeout for update operations. Defaults to `90m`.
- `delete` - (Optional) Timeout for delete operations. Defaults to `90m`.
DESCRIPTION
}

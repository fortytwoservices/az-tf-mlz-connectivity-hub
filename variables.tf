variable "parent_id" {
  type        = string
  description = "Resource ID of the connectivity subscription (`/subscriptions/<id>`). The module creates one resource group in it per hub, and one for the private DNS zones."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/subscriptions", var.parent_id))
    error_message = "`parent_id` must be a subscription resource ID, `/subscriptions/<id>`."
  }
}

variable "hub_virtual_networks" {
  type = map(object({
    location                      = string
    address_space                 = list(string)
    is_primary                    = optional(bool, false)
    name                          = optional(string)
    resource_group_name           = optional(string)
    routing_supernet              = optional(list(string), [])
    spoke_address_prefixes        = optional(map(string), {})
    virtual_network_dns_servers   = optional(list(string))
    gateway_subnet_address_prefix = optional(string)
    gateway_route_table_name      = optional(string)
    firewall = optional(object({
      name                             = optional(string)
      sku_tier                         = optional(string, "Standard")
      zones                            = optional(list(string))
      subnet_address_prefix            = string
      management_subnet_address_prefix = optional(string)
      public_ip_name                   = optional(string)
      management_public_ip_name        = optional(string)
      route_table_name                 = optional(string)
      default_route = optional(object({
        enabled             = optional(bool, true)
        next_hop_type       = optional(string, "Internet")
        next_hop_ip_address = optional(string)
      }), {})
      firewall_policy_id = optional(string)
      firewall_policy = optional(object({
        name                     = optional(string)
        base_policy_id           = optional(string)
        threat_intelligence_mode = optional(string, "Alert")
        dns_proxy_enabled        = optional(bool)
        dns_servers              = optional(list(string))
      }), {})
    }))
    nat_gateway = optional(object({
      name                    = optional(string)
      sku_name                = optional(string, "StandardV2")
      zones                   = optional(list(string))
      idle_timeout_in_minutes = optional(number, 4)
      public_ip_name          = optional(string)
    }))
    bastion = optional(object({
      name                   = optional(string)
      subnet_address_prefix  = string
      sku                    = optional(string, "Standard")
      zones                  = optional(list(string))
      public_ip_name         = optional(string)
      scale_units            = optional(number, 2)
      copy_paste_enabled     = optional(bool, true)
      file_copy_enabled      = optional(bool, false)
      ip_connect_enabled     = optional(bool, false)
      kerberos_enabled       = optional(bool, false)
      shareable_link_enabled = optional(bool, false)
      tunneling_enabled      = optional(bool, false)
    }))
    dns_resolver = optional(object({
      name                           = optional(string)
      inbound_subnet_address_prefix  = string
      inbound_subnet_name            = optional(string, "snet-dns-resolver-inbound")
      inbound_endpoint_name          = optional(string)
      outbound_subnet_address_prefix = optional(string)
      outbound_subnet_name           = optional(string, "snet-dns-resolver-outbound")
      outbound_endpoint_name         = optional(string)
    }))
    vpn_gateway = optional(object({
      name           = optional(string)
      sku            = optional(string, "VpnGw1AZ")
      vpn_generation = optional(string)
      active_active  = optional(bool, false)
      bgp = optional(object({
        asn         = optional(number, 65515)
        peer_weight = optional(number, 0)
      }))
      point_to_site = optional(object({
        address_space = list(string)
        protocols     = optional(list(string), ["OpenVPN"])
        entra_id = optional(object({
          tenant_id = string
          audience  = optional(string, "c632b3df-fb67-4d84-bdcf-b95ad541b5c8")
        }))
        root_certificates    = optional(map(string), {})
        revoked_certificates = optional(map(string), {})
      }))
      public_ip_names = optional(list(string), [])
      local_network_gateways = optional(map(object({
        name               = string
        gateway_ip_address = optional(string)
        fqdn               = optional(string)
        address_prefixes   = optional(list(string), [])
        bgp = optional(object({
          asn                 = number
          bgp_peering_address = string
          peer_weight         = optional(number, 0)
        }))
      })), {})
      connections = optional(map(object({
        name                               = string
        type                               = optional(string, "IPsec")
        local_network_gateway_key          = optional(string)
        local_network_gateway_id           = optional(string)
        peer_virtual_network_gateway_id    = optional(string)
        enable_bgp                         = optional(bool, false)
        connection_protocol                = optional(string, "IKEv2")
        connection_mode                    = optional(string, "Default")
        dpd_timeout_seconds                = optional(number, 45)
        routing_weight                     = optional(number, 0)
        use_policy_based_traffic_selectors = optional(bool, false)
        ipsec_policy = optional(object({
          dh_group               = string
          ike_encryption         = string
          ike_integrity          = string
          ipsec_encryption       = string
          ipsec_integrity        = string
          pfs_group              = string
          sa_data_size_kilobytes = optional(number, 102400000)
          sa_lifetime_seconds    = optional(number, 27000)
        }))
        custom_bgp_addresses = optional(map(string), {})
        secret_version       = optional(string, "1")
      })), {})
    }))
    express_route_gateway = optional(object({
      name = optional(string)
      sku  = optional(string, "ErGw1AZ")
      express_route_scale_units = optional(object({
        min = number
        max = number
      }))
      connections = optional(map(object({
        name                         = string
        express_route_circuit_id     = string
        routing_weight               = optional(number, 0)
        express_route_gateway_bypass = optional(bool, false)
        secret_version               = optional(string, "1")
      })), {})
    }))
  }))
  nullable    = false
  description = <<DESCRIPTION
The hub virtual networks, keyed by region key (the key of the region's entry in the `connectivity` output, usually the region's name). Exactly one is primary: the private DNS zones live in its region. Each hub gets a resource group of its own (Cloud Adoption Framework: each region's hub resources in their own resource group). Every name is optional: an explicit name wins, else `naming` makes one. Subnets are created for the components that are set; workloads do not belong in the hub (Microsoft Learn, "Use Azure Firewall to route a multi-hub and spoke topology"), so there are no others.

- `location` - Azure region of the hub and of everything in its resource group.
- `address_space` - The hub virtual network's address ranges, holding the subnets below.
- `is_primary` - (Optional) Whether this is the primary region. Exactly one hub is. Defaults to `false`.
- `name` - (Optional) Name of the hub virtual network.
- `resource_group_name` - (Optional) Name of the resource group the module creates for the hub and its resources.
- `routing_supernet` - (Optional) The region's summary address ranges (its hub and spokes). Other hubs route them to this hub's firewall, and they are published in the `connectivity` output.
- `spoke_address_prefixes` - (Optional) The address spaces of this region's spokes, keyed by a stable name. With a firewall and a gateway, the `GatewaySubnet` route table sends each to the firewall, so traffic from on-premises is inspected both ways. They must be the spokes' exact prefixes: a summary loses to the peerings' more specific system routes (Microsoft Learn). Add a spoke's prefix here before vending it.
- `virtual_network_dns_servers` - (Optional) Custom DNS servers of the hub virtual network. Null (the default) keeps Azure-provided DNS, which Microsoft recommends in a gateway's virtual network (VPN Gateway FAQ). Set it, for example to the resolver's inbound address, for point-to-site clients to resolve private DNS zones; the servers must forward to Azure DNS (168.63.129.16), as the resolver and a firewall DNS proxy do.
- `gateway_subnet_address_prefix` - (Optional) Address prefix of `GatewaySubnet`, required with a gateway: /27 or larger, /26 or larger for `ErGwScale` or for a VPN and an ExpressRoute gateway together (Microsoft Learn recommends /26).
- `gateway_route_table_name` - (Optional) Name of the `GatewaySubnet` route table, created for a hub with a firewall and a gateway.
- `firewall` - (Optional) An Azure Firewall through `az-tf-mlz-azure-firewall`, in an `AzureFirewallSubnet` the module creates:
  - `name` - (Optional) Name of the firewall.
  - `sku_tier` - (Optional) `Basic`, `Standard` (default) or `Premium`.
  - `zones` - (Optional) Availability zones of the firewall. Null leaves them out (Microsoft: none for Basic).
  - `subnet_address_prefix` - Address prefix of `AzureFirewallSubnet`, /26 or larger. The firewall's private address is its fifth address (`cidrhost(prefix, 4)`), which the routes use and the module checks against Azure's.
  - `management_subnet_address_prefix` - (Optional) Address prefix of `AzureFirewallManagementSubnet` (/26 or larger): the management NIC, required for Basic and for forced tunnelling. Adding or removing it replaces the firewall.
  - `public_ip_name`, `management_public_ip_name` - (Optional) Names of the public IP addresses the module creates for the firewall and its management NIC.
  - `route_table_name` - (Optional) Name of the `AzureFirewallSubnet` route table.
  - `default_route` - (Optional) The firewall subnet's default route: `next_hop_type` `Internet` (default), or for forced tunnelling `VirtualAppliance` (with `next_hop_ip_address`) or `VirtualNetworkGateway`; `enabled = false` sends no default route, so a default route learned through BGP from the gateway applies. Anything but `Internet` needs the management NIC (Microsoft Learn, "Azure Firewall forced tunneling").
  - `firewall_policy_id` - (Optional) Resource ID of an existing firewall policy. When set, the module creates no policy and `firewall_policy` is ignored.
  - `firewall_policy` - (Optional) The policy the module creates, with the firewall's tier: `name`, `base_policy_id` (a parent policy in the same region), `threat_intelligence_mode` (`Alert` by default, `Deny` or `Off`; Basic is alert-only), `dns_proxy_enabled` (default: on, except on Basic) and `dns_servers` (default: the hub resolver's inbound address, else Azure DNS). A Basic policy takes neither: it has no DNS settings at all. Rules are not set here: a rules state calls the firewall module's `//modules/rule_collection_group` with the `firewall_policy_id` from the `connectivity` output.
- `nat_gateway` - (Optional) A NAT gateway through `az-tf-mlz-nat-gateway` on `AzureFirewallSubnet`, the firewall's outbound path (Microsoft Learn: up to 16 public IPs, far more SNAT ports); needs `firewall`. `sku_name` `StandardV2` (default, zone-redundant: the one for a zone-redundant firewall) or `Standard` with at most one zone in `zones`; `idle_timeout_in_minutes` (4 to 120); `name` and `public_ip_name` of the public IP address the module creates for it.
- `bastion` - (Optional) Azure Bastion through `az-tf-mlz-bastion`, in an `AzureBastionSubnet` the module creates from `subnet_address_prefix` (/26 or larger), with a public IP address it creates (`public_ip_name`). `sku` is `Basic`, `Standard` (default) or `Premium`: all reach VMs in peered virtual networks; Developer is not offered (no peering, no subnet). `zones`, `scale_units` and the feature flags are the Bastion module's, with its defaults.
- `dns_resolver` - (Optional) A DNS private resolver through `az-tf-mlz-dns-resolver`, with an inbound endpoint in a subnet the module creates from `inbound_subnet_address_prefix` (/28 to /24, delegated to the resolver) at its fifth address (`cidrhost(prefix, 4)`), and an outbound endpoint when `outbound_subnet_address_prefix` is set. Forwarding rulesets are the caller's: call `//modules/forwarding_ruleset` of the resolver module with the outbound endpoint's ID (do not link a ruleset that forwards to the inbound endpoint to the hub: Learn, a DNS loop).
- `vpn_gateway` - (Optional) A VPN gateway through `az-tf-mlz-virtual-network-gateway` in `GatewaySubnet`: `name`, `sku` (`VpnGw1AZ` default to `VpnGw5AZ`), `vpn_generation`, `active_active`, `bgp` and `point_to_site` as that module takes them. The module creates its IP configurations (`ipconfig1`, `ipconfig2` when active-active, `ipconfig3` for point-to-site on an active-active gateway) and their public IP addresses, named by `public_ip_names` in that order, else by the template. `local_network_gateways` (sites) and `connections` are that module's, without their own locks, role assignments and diagnostic settings; connection keys come from `connection_secrets`.
- `express_route_gateway` - (Optional) An ExpressRoute gateway through `az-tf-mlz-virtual-network-gateway` in `GatewaySubnet` (Azure assigns its public IP address): `name`, `sku` (`ErGw1AZ` default, `ErGw2AZ`, `ErGw3AZ` or `ErGwScale` with `express_route_scale_units`), and `connections` to circuits (`express_route_circuit_id`; an authorization key, for a circuit in another subscription, through `connection_secrets`). A VPN and an ExpressRoute gateway can share `GatewaySubnet`; the gateway module has not tested that.
DESCRIPTION

  validation {
    condition     = length([for hub in var.hub_virtual_networks : hub if hub.is_primary]) == 1
    error_message = "Exactly one of `hub_virtual_networks` must have `is_primary = true`."
  }
  validation {
    condition = var.naming != null || alltrue([for hub in var.hub_virtual_networks : alltrue([
      hub.name != null && hub.resource_group_name != null,
      hub.firewall == null ? true : hub.firewall.name != null && hub.firewall.public_ip_name != null && hub.firewall.route_table_name != null && (hub.firewall.firewall_policy_id != null || hub.firewall.firewall_policy.name != null),
      hub.firewall == null ? true : hub.firewall.management_subnet_address_prefix == null || hub.firewall.management_public_ip_name != null,
      hub.nat_gateway == null ? true : hub.nat_gateway.name != null && hub.nat_gateway.public_ip_name != null,
      hub.bastion == null ? true : hub.bastion.name != null && hub.bastion.public_ip_name != null,
      hub.dns_resolver == null ? true : hub.dns_resolver.name != null && hub.dns_resolver.inbound_endpoint_name != null && (hub.dns_resolver.outbound_subnet_address_prefix == null || hub.dns_resolver.outbound_endpoint_name != null),
      hub.vpn_gateway == null ? true : hub.vpn_gateway.name != null && length(hub.vpn_gateway.public_ip_names) >= (hub.vpn_gateway.active_active ? 2 : 1) + (hub.vpn_gateway.active_active && hub.vpn_gateway.point_to_site != null ? 1 : 0),
      hub.express_route_gateway == null ? true : hub.express_route_gateway.name != null,
      hub.firewall == null || (hub.vpn_gateway == null && hub.express_route_gateway == null) ? true : hub.gateway_route_table_name != null,
    ])])
    error_message = "Without `naming`, every component needs its name: each hub's `name` and `resource_group_name`; the firewall's `name`, `public_ip_name`, `route_table_name`, its created policy's `name` and, with a management subnet, `management_public_ip_name`; the NAT gateway's and Bastion's `name` and `public_ip_name`; the resolver's and its endpoints' names; each gateway's `name` and the VPN gateway's `public_ip_names` (one per IP configuration); and `gateway_route_table_name` for a hub with a firewall and a gateway."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : (
      length(hub.address_space) > 0 &&
      alltrue([for range in concat(hub.address_space, hub.routing_supernet, values(hub.spoke_address_prefixes)) : can(cidrhost(range, 0))]) &&
      !contains(values(hub.spoke_address_prefixes), "0.0.0.0/0")
    )])
    error_message = "Each hub needs an `address_space`, and its `address_space`, `routing_supernet` and `spoke_address_prefixes` must be ranges in CIDR notation; `0.0.0.0/0` is not a spoke prefix (a default route on `GatewaySubnet` is not supported)."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.firewall == null ? true : (
      contains(["Basic", "Standard", "Premium"], hub.firewall.sku_tier) &&
      !(hub.firewall.sku_tier == "Basic" && (hub.firewall.firewall_policy.dns_proxy_enabled == true || length(coalesce(hub.firewall.firewall_policy.dns_servers, [])) > 0))
    )])
    error_message = "A firewall's `sku_tier` must be `Basic`, `Standard` or `Premium`, and a Basic firewall's policy takes no DNS settings (`dns_proxy_enabled`, `dns_servers`)."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.firewall == null ? true : alltrue([
      for prefix in compact([hub.firewall.subnet_address_prefix, hub.firewall.management_subnet_address_prefix]) :
      can(cidrhost(prefix, 0)) && try(tonumber(split("/", prefix)[1]) <= 26, false)
    ])])
    error_message = "A firewall's `subnet_address_prefix` and `management_subnet_address_prefix` must be ranges in CIDR notation of /26 or larger."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.firewall == null ? true : (
      (hub.firewall.sku_tier != "Basic" || hub.firewall.management_subnet_address_prefix != null) &&
      (hub.firewall.default_route.enabled && hub.firewall.default_route.next_hop_type == "Internet" || hub.firewall.management_subnet_address_prefix != null)
    )])
    error_message = "A Basic firewall, and forced tunnelling (a `default_route` other than `Internet`, or none), need the management NIC: set `management_subnet_address_prefix`."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.firewall == null ? true : (
      contains(["Internet", "VirtualAppliance", "VirtualNetworkGateway"], hub.firewall.default_route.next_hop_type) &&
      (hub.firewall.default_route.next_hop_type == "VirtualAppliance") == (hub.firewall.default_route.next_hop_ip_address != null) &&
      (hub.firewall.default_route.next_hop_type != "VirtualNetworkGateway" || hub.vpn_gateway != null)
    )])
    error_message = "A firewall's `default_route.next_hop_type` must be `Internet`, `VirtualAppliance` (with `next_hop_ip_address`, and only then) or `VirtualNetworkGateway` (with a `vpn_gateway`)."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.nat_gateway == null ? true : (
      hub.firewall != null &&
      contains(["Standard", "StandardV2"], hub.nat_gateway.sku_name) &&
      (hub.nat_gateway.zones == null || hub.nat_gateway.sku_name == "Standard")
    )])
    error_message = "A NAT gateway needs a `firewall` (it is attached to `AzureFirewallSubnet`); its `sku_name` must be `Standard` or `StandardV2`, and only Standard takes `zones`."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.bastion == null ? true : (
      contains(["Basic", "Standard", "Premium"], hub.bastion.sku) &&
      can(cidrhost(hub.bastion.subnet_address_prefix, 0)) &&
      try(tonumber(split("/", hub.bastion.subnet_address_prefix)[1]) <= 26, false)
    )])
    error_message = "Bastion's `sku` must be `Basic`, `Standard` or `Premium` (Developer supports no peering and takes no subnet), and its `subnet_address_prefix` a range in CIDR notation of /26 or larger."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.dns_resolver == null ? true : alltrue([
      for prefix in compact([hub.dns_resolver.inbound_subnet_address_prefix, hub.dns_resolver.outbound_subnet_address_prefix]) :
      can(cidrhost(prefix, 0)) && try(tonumber(split("/", prefix)[1]) >= 24 && tonumber(split("/", prefix)[1]) <= 28, false)
    ])])
    error_message = "A resolver's subnet address prefixes must be ranges in CIDR notation from /28 to /24."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : (hub.vpn_gateway == null && hub.express_route_gateway == null) == (hub.gateway_subnet_address_prefix == null) && (
      hub.gateway_subnet_address_prefix == null ? true :
      can(cidrhost(hub.gateway_subnet_address_prefix, 0)) && try(tonumber(split("/", hub.gateway_subnet_address_prefix)[1]) <= (
        hub.vpn_gateway != null && hub.express_route_gateway != null || try(hub.express_route_gateway.sku, "") == "ErGwScale" ? 26 : 27
      ), false)
    )])
    error_message = "`gateway_subnet_address_prefix` is required with a gateway and taken by no hub without one: a range in CIDR notation of /27 or larger, /26 or larger for `ErGwScale` or for a VPN and an ExpressRoute gateway together."
  }
  validation {
    condition = alltrue([for hub in var.hub_virtual_networks : hub.vpn_gateway == null || hub.express_route_gateway == null ? true : (
      length(setintersection(keys(hub.vpn_gateway.connections), keys(hub.express_route_gateway.connections))) == 0
    )])
    error_message = "A hub's VPN and ExpressRoute connections need distinct keys: `connection_secrets` are keyed `<hub key>/<connection key>`."
  }
}

variable "mesh_peering_enabled" {
  type        = bool
  default     = true
  description = "(Optional) Whether every pair of hubs is peered both ways (forwarded traffic allowed, no gateway transit between hubs), with each hub's `AzureFirewallSubnet` routing the other regions' `routing_supernet` to their firewalls and its `GatewaySubnet` routing them to its own firewall (Microsoft Learn, \"Use Azure Firewall to route a multi-hub and spoke topology\"). The Cloud Adoption Framework recommends global peering to connect two regions' hubs and Virtual WAN beyond two regions. `false` leaves the hubs unpeered, for example when ExpressRoute connects them. Defaults to `true`."
  nullable    = false
}

variable "connection_secrets" {
  type        = map(string)
  default     = {}
  ephemeral   = true
  sensitive   = true
  description = "(Optional) The gateways' connection keys, keyed `<hub key>/<connection key>`: the pre-shared key of each `IPsec` or `Vnet2Vnet` connection (required), and the authorization key of an ExpressRoute connection to a circuit in another subscription. Ephemeral and write-only: sent to Azure, never stored in state; change the connection's `secret_version` to send a new key."
  nullable    = false
}

variable "ddos_protection_plan_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of an existing DDoS protection plan, applied to every hub virtual network and published per region in the `connectivity` output for subscription vending. The Cloud Adoption Framework asks for one plan in the connectivity subscription for every virtual network; it is created by the connectivity root, not here, because it serves the whole tenant and is billed by the month."

  validation {
    condition     = var.ddos_protection_plan_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/ddosProtectionPlans", var.ddos_protection_plan_id))
    error_message = "`ddos_protection_plan_id` must be a DDoS protection plan resource ID."
  }
}

variable "private_dns_zones" {
  type = object({
    resource_group_name = optional(string)
    zone_name_filter    = optional(string)
    excluded_zones      = optional(list(string), [])
    additional_zones    = optional(map(string), {})
  })
  default     = null
  description = <<DESCRIPTION
(Optional) The Private Link private DNS zones, through `Azure/avm-ptn-network-private-link-private-dns-zones/azurerm` v0.23.2, in one resource group the module creates in the primary hub's region, each linked to every hub virtual network (where the resolver resolves them). Null (the default) creates none: keep them in a state of their own and link them to each region's `hub_virtual_network_id`.

- `resource_group_name` - (Optional) Name of their resource group. Defaults to the primary hub's template name for the `resource_group_private_dns` key.
- `zone_name_filter` - (Optional) A regular expression: only zones whose name (as the pattern lists it, with `{regionName}` and `{regionCode}` placeholders) matches are created, in the primary hub's region only. Null: every zone for the primary region, plus each other hub's regional zones.
- `excluded_zones` - (Optional) Zone names or keys of the pattern's list to leave out.
- `additional_zones` - (Optional) More zones for the primary region, by a stable key.
DESCRIPTION
}

variable "naming" {
  type = object({
    template             = string
    variables            = optional(map(string), {})
    instance             = optional(number)
    slug_overrides       = optional(map(string))
    custom_override_file = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
(Optional) A naming template for every component left without an explicit name, through `Azure/avm-utl-naming/azure` v0.2.0, called once per hub. Null: every component needs an explicit name.

- `template` - The module's `naming_templates.name`, with tokens escaped (`$$${slug}` in HCL passes `$${slug}`). The module adds a `region` token, the hub region's short name (`geo_code` from `Azure/avm-utl-regions`, for example `sdc` for swedencentral): use it, or the names of two hubs collide. Example: `"az$$${separator}$$${slug}$$${separator}$$${landing_zone}$$${separator}$$${environment}$$${separator}$$${region}$$${separator}$$${instance}"`.
- `variables` - (Optional) More template tokens, for example `{ landing_zone = "conn", environment = "pd" }`. Not the naming module's own tokens (`name`, `prefix`, `suffix`, `slug`, `separator`, `unique`, `unique_seed`, `instance`, `terraform_key`, `resource_type`, `variant`, `min_length`, `max_length`), which it refuses, nor `region`, which this module sets.
- `instance` - (Optional) The instance number, formatted as `001`.
- `slug_overrides` - (Optional) Slugs by catalogue key, for example `{ public_ip_address_firewall = "pipfw" }`.
- `custom_override_file` - (Optional) Path of a catalogue override file (`custom_override_file` of the naming module). Defaults to this module's `naming-overrides.json`, which lets NAT gateway names have hyphens and adds the keys below for resources a hub has several of; a file of your own must carry them too.

Catalogue keys used: `resource_group`, `virtual_network`, `azure_firewall`, `firewall_policy`, `nat_gateway`, `bastion_host`, `dns_resolver`, `dns_resolver_inbound_endpoint`, `dns_resolver_outbound_endpoint`, `virtual_network_gateway`, `virtual_network_gateway_express_route_gateway`, and from this module's override file `public_ip_address_firewall` (slug `pip-afw`), `public_ip_address_firewall_management` (`pip-afwm`), `public_ip_address_nat_gateway` (`pip-ng`), `public_ip_address_bastion` (`pip-bas`), `public_ip_address_vpn_gateway_1` to `_3` (`pip-vgw1` to `pip-vgw3`), `route_table_firewall` (`rt-afw`), `route_table_gateway` (`rt-vgw`) and `resource_group_private_dns` (`rg-pdns`).
DESCRIPTION
}

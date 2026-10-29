# az-tf-mlz-connectivity-hub

The hub-and-spoke topology of Fortytwo's managed landing zone (MLZ), in AzAPI: one hub virtual network per
region, each in its own resource group, with its Azure Firewall, NAT gateway, Azure Bastion, DNS private
resolver and virtual network gateways, the hubs peered with each other and routed through their
firewalls. It replaces the azurerm-based `avm-ptn-alz-connectivity-hub-and-spoke-vnet`; its building
blocks are MLZ modules and AVM's AzAPI modules.

| Resource | From |
|---|---|
| One resource group per hub (and one for the private DNS zones) | this module |
| Hub virtual networks, their subnets and the peerings between hubs | `Azure/avm-res-network-virtualnetwork/azurerm` 0.22.3 (AzAPI) |
| Route tables of `AzureFirewallSubnet` and `GatewaySubnet`, with their routes | `Azure/avm-ptn-alz-sub-vending/azure//modules/route-table` 0.3.4 (AzAPI) |
| Firewall and policy, with their public IP addresses | [`az-tf-mlz-azure-firewall`](https://github.com/fortytwoservices/az-tf-mlz-azure-firewall) |
| NAT gateway on `AzureFirewallSubnet` | [`az-tf-mlz-nat-gateway`](https://github.com/fortytwoservices/az-tf-mlz-nat-gateway) |
| Azure Bastion | [`az-tf-mlz-bastion`](https://github.com/fortytwoservices/az-tf-mlz-bastion) |
| DNS private resolver and its endpoints | [`az-tf-mlz-dns-resolver`](https://github.com/fortytwoservices/az-tf-mlz-dns-resolver) |
| VPN and ExpressRoute gateways, sites and connections | [`az-tf-mlz-virtual-network-gateway`](https://github.com/fortytwoservices/az-tf-mlz-virtual-network-gateway) |
| Private Link private DNS zones, linked to every hub | `Azure/avm-ptn-network-private-link-private-dns-zones/azurerm` 0.23.2 (AzAPI) |
| Names from a template | `Azure/avm-utl-naming/azure` 0.2.0, `Azure/avm-utl-regions/azurerm` 0.13.0 |

Spokes are created and peered by subscription vending, which reads the `connectivity` output (the contract
shared with `az-tf-mlz-connectivity-vwan`: hub network IDs, firewall address and policy, DNS servers, the
spokes' default route). Firewall rules live in a rules state that calls the firewall module's
`//modules/rule_collection_group` with the policy ID from that output, so a rule change never plans the
hubs. The DDoS protection plan is the connectivity root's: pass its ID.

## How it behaves

The design follows the Cloud Adoption Framework's "Traditional Azure networking topology", the
Architecture Center's "Hub-spoke network topology in Azure" and Azure Firewall's "Use Azure Firewall to
route a multi-hub and spoke topology".

- **Subnets from what a hub has:** `AzureFirewallSubnet` and, for Basic or forced tunnelling,
  `AzureFirewallManagementSubnet`; `GatewaySubnet` with a gateway; `AzureBastionSubnet` with Bastion; the
  resolver's two delegated subnets. Workloads and shared services belong in spokes, not in the hub.
- **Routing.** The firewall's private address is its subnet's fifth address, known before apply (the
  module checks Azure's). `AzureFirewallSubnet` sends `0.0.0.0/0` to the Internet, or for forced
  tunnelling to an appliance, the VPN gateway, or nowhere so a BGP-learned default applies (the management
  NIC is required then), and each other region's `routing_supernet` to that region's firewall.
  `GatewaySubnet` sends each spoke's exact prefix (`spoke_address_prefixes`) and the other regions to the
  hub's firewall, so traffic from on-premises is inspected both ways: add a spoke's prefix before vending
  it. Both keep gateway route propagation on. Spokes get `spoke_default_routes` from the contract, with
  propagation off.
- **The mesh.** Every pair of hubs is peered both ways, with forwarded traffic allowed and no gateway
  transit between hubs (`mesh_peering_enabled`). Microsoft recommends this for two regions and Virtual WAN
  beyond.
- **DNS.** A created firewall policy proxies DNS to the resolver's inbound endpoint, at its subnet's fifth
  address (except on Basic, which has no DNS proxy); the contract's `dns_servers` is then the firewall's
  address, else the resolver's. The hub virtual network keeps Azure-provided DNS unless
  `virtual_network_dns_servers` is set, as Microsoft recommends where a VPN gateway lives.
- **Names.** Each component takes an explicit name; without one, `naming` makes it from a template, with
  the hub region's short name as the `region` token and this module's catalogue additions for the
  resources a hub has several of (public IP addresses, route tables).
- **Serialisation and timing.** Writes to a virtual network (subnets, peerings) are serialised on it. A
  VPN gateway takes 20 to 60 minutes per write and a firewall tens of minutes, so `timeouts` default to 90
  minutes, and `retry` covers the transient errors of all the modules called. A gateway write that fails
  with `VmssGatewayDeploymentFailed` ("intermittent error") succeeds when the apply is run again.

Not in this release: locks and role assignments on the components, NSGs, IP address management, Route
Server, Virtual Network Manager, and re-syncing the peerings after a hub's address space changes.

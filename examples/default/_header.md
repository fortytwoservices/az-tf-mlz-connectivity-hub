# Default example

One hub in swedencentral, named from a template: its virtual network, a Basic Azure Firewall with its
management NIC and a policy, a StandardV2 NAT gateway as the firewall's outbound path, a DNS private
resolver with both endpoints, two Private Link DNS zones linked to the hub, the route tables of the
firewall subnet, and diagnostic settings to a Log Analytics workspace. Basic keeps the test cheap; a
production hub uses Standard or Premium.

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy.

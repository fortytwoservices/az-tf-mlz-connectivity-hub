output "connectivity" {
  description = "The contract for subscription vending and firewall rules."
  value       = module.connectivity.connectivity
}

output "hub_virtual_networks" {
  description = "Each hub's resources."
  value       = module.connectivity.hub_virtual_networks
}

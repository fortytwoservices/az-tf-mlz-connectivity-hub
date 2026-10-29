variable "diagnostic_settings" {
  type = map(object({
    name = optional(string, null)
    logs = optional(set(object({
      category       = optional(string, null)
      category_group = optional(string, null)
      enabled        = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    metrics = optional(set(object({
      category = optional(string, null)
      enabled  = optional(bool, true)
      retention_policy = optional(object({
        days    = optional(number, 0)
        enabled = optional(bool, false)
      }), {})
    })), [])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings : alltrue([
        for l in v.logs : (l.category != null) != (l.category_group != null)
      ])
    ])
    error_message = "Each log entry must set exactly one of `category` or `category_group`."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.OperationalInsights/workspaces", v.workspace_resource_id))
    ])
    error_message = "Each `workspace_resource_id` must be a valid Log Analytics workspace resource ID, or null."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.storage_account_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.Storage/storageAccounts", v.storage_account_resource_id))
    ])
    error_message = "Each `storage_account_resource_id` must be a valid storage account resource ID, or null."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.event_hub_authorization_rule_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.EventHub/namespaces/authorizationRules", v.event_hub_authorization_rule_resource_id))
    ])
    error_message = "Each `event_hub_authorization_rule_resource_id` must be a valid Event Hub namespace authorization rule resource ID, or null."
  }
  description = <<DESCRIPTION
A map of diagnostic settings to create on each hub's Azure Firewall, Azure Bastion, DNS private resolver and virtual network gateways. Azure offers no log categories on the resolver, so it receives each setting with `logs` removed, and none that has no `metrics`. The hub virtual networks, the firewall policies, the NAT gateways, the route tables and the gateway connections get none from this module. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `logs` - (Optional) A set of log entries to send to the destination. Each entry has the following attributes:
  - `category` - (Optional) The name of a specific log category to enable. Mutually exclusive with `category_group`.
  - `category_group` - (Optional) The name of a log category group to enable (for example, `allLogs` or `audit`). Mutually exclusive with `category`.
  - `enabled` - (Optional) Whether the log entry is enabled. Defaults to `true`.
  - `retention_policy` - (Optional) The retention policy for the log entry.
    - `days` - (Optional) The retention period in days. Defaults to `0` (retain indefinitely).
    - `enabled` - (Optional) Whether the retention policy is enabled. Defaults to `false`.
- `metrics` - (Optional) A set of metric entries to send to the destination. Each entry has the following attributes:
  - `category` - (Optional) The name of the metric category to enable.
  - `enabled` - (Optional) Whether the metric entry is enabled. Defaults to `true`.
  - `retention_policy` - (Optional) The retention policy for the metric entry, with the same `days` and `enabled` attributes as `logs.retention_policy`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic Logs.
DESCRIPTION
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of every resource the module creates that takes tags: the resource groups, the hub virtual networks, the route tables, the firewalls and their policies, the NAT gateways, Bastion, the resolvers and their endpoints, the gateways, the public IP addresses of all of these, and the private DNS zones. Peerings, routes, subnets and the gateways' sites and connections take none."
}

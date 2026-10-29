# Reads resources back from Azure, so a test can check what another write left in place.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "resource_ids" {
  type        = map(string)
  description = "Resource IDs to read, by key, each `<type>@<api-version>|<resource ID>`."
}

data "azapi_resource" "this" {
  for_each = var.resource_ids

  type                   = split("|", each.value)[0]
  resource_id            = split("|", each.value)[1]
  response_export_values = ["properties", "tags"]
}

output "properties" {
  value = { for key, resource in data.azapi_resource.this : key => resource.output.properties }
}

output "tags" {
  value = { for key, resource in data.azapi_resource.this : key => try(resource.output.tags, null) }
}

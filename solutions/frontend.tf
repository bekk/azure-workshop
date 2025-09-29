resource "azurerm_storage_account" "todo_frontend" {
  name                            = "sttodo${local.id}"
  resource_group_name             = azurerm_resource_group.todo.name
  location                        = azurerm_resource_group.todo.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true
  enable_https_traffic_only       = false # We'll change this in a later task
  min_tls_version                 = "TLS1_2"

  static_website {
    index_document = "index.html"
  }
}

locals {
  # 'path.module' is the path to the current module, i.e., the path to the 'infra/' directory
  frontend_dir = "${path.module}/../frontend_dist"
  # get all files in the `frontend_dist` dir
  frontend_files = fileset(local.frontend_dir, "**")

  # this is a map (key-value pairs)
  mime_types = {
    ".js"   = "application/javascript"
    ".html" = "text/html"
  }
}

resource "azurerm_storage_blob" "frontend_files" {
  for_each = local.frontend_files

  name                   = each.value
  storage_account_name   = azurerm_storage_account.todo_frontend.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "${local.frontend_dir}/${each.value}"
  content_type           = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  content_md5            = filemd5("${local.frontend_dir}/${each.value}")
}

# Azure Front Door module
module "azure_frontdoor" {
  source = "../modules/azure-frontdoor"

  # Required parameters
  unique_id           = local.id
  resource_group_name = azurerm_resource_group.todo.name
  origin_host_name    = azurerm_storage_account.todo_frontend.primary_web_host

  # Enable custom domain with automatic DNS management
  enable_custom_domain = true

  # DNS configuration
  dns_zone_name                = data.azurerm_dns_zone.cloudlabs_azure_no.name
  dns_zone_resource_group_name = data.azurerm_dns_zone.cloudlabs_azure_no.resource_group_name

  # Optional parameters (using defaults where appropriate)
  origin_host_header = azurerm_storage_account.todo_frontend.primary_web_host
}

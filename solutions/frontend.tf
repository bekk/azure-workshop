resource "azurerm_storage_account" "todo_frontend" {
  name = "sttodo${local.id}"
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
  frontend_dir   = "${path.module}/../frontend_dist"
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


resource "azurerm_cdn_profile" "todo_cdn_profile" {
  name                = "cdnp-todo-${local.id}"
  location            = azurerm_resource_group.todo.location
  resource_group_name = azurerm_resource_group.todo.name
  # Microsoft is fastest to get up and running for the workshop. Also cheapest, 
  # and we don't need special features provided by other alternatives
  sku = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "todo_cdn_endpoint" {
  name                = "cdne-todo-${local.id}"
  location            = azurerm_resource_group.todo.location
  resource_group_name = azurerm_resource_group.todo.name
  profile_name        = azurerm_cdn_profile.todo_cdn_profile.name

  # Configure the CDN endpoint to point to the storage container
  origin_host_header = azurerm_storage_account.todo_frontend.primary_web_host
  origin {
    name      = "origin"
    host_name = azurerm_storage_account.todo_frontend.primary_web_host
  }

  # Not required, and probably not what you want in production, but simplifies debugging configuration
  global_delivery_rule {
    cache_expiration_action {
      behavior = "BypassCache"
    }
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "todo_frontend" {
  name            = local.id
  cdn_endpoint_id = azurerm_cdn_endpoint.todo_cdn_endpoint.id
  host_name       = trimsuffix(azurerm_dns_cname_record.todo_cdn.fqdn, ".")
}



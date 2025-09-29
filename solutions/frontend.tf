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

# Azure Front Door Standard (replaces classic CDN resources)
resource "azurerm_cdn_frontdoor_profile" "todo" {
  name                = "fdp-todo-${local.id}"
  resource_group_name = azurerm_resource_group.todo.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "todo_frontdoor" {
  name                      = "fde-todo-${local.id}"
  cdn_frontdoor_profile_id  = azurerm_cdn_frontdoor_profile.todo.id
}

resource "azurerm_cdn_frontdoor_origin_group" "todo" {
  name                     = "og-storage-${local.id}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.todo.id

  load_balancing {}
  health_probe {
    protocol            = "Https"
    interval_in_seconds = 120
    path                = "/"
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_origin" "storage_static_site" {
  name                          = "origin-storage-${local.id}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.todo.id
  enabled                       = true

  certificate_name_check_enabled = false
  host_name         = azurerm_storage_account.todo_frontend.primary_web_host
  origin_host_header = azurerm_storage_account.todo_frontend.primary_web_host

  http_port  = 80
  https_port = 443

  priority = 1
  weight   = 1000
}

resource "azurerm_cdn_frontdoor_route" "todo" {
  name                           = "route-all-${local.id}"
  cdn_frontdoor_endpoint_id      = azurerm_cdn_frontdoor_endpoint.todo_frontdoor.id
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.todo.id
  supported_protocols            = ["Http", "Https"]
  https_redirect_enabled         = true
  patterns_to_match              = ["/*"]
  forwarding_protocol            = "MatchRequest"
  link_to_default_domain         = true
  cdn_frontdoor_origin_ids       = [azurerm_cdn_frontdoor_origin.storage_static_site.id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.todo_frontend.id]

  cache {
    # Disabled caching similar to previous BypassCache setup; adjust later
    query_string_caching_behavior = "IgnoreQueryString"
  }
}

# Custom domain (CNAME defined in dns.tf). TLS managed certificate.
resource "azurerm_cdn_frontdoor_custom_domain" "todo_frontend" {
  name                     = "cdom-${local.id}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.todo.id
  dns_zone_id = data.azurerm_dns_zone.cloudlabs_azure_no.id
  host_name                = trimsuffix(azurerm_dns_cname_record.todo_cdn.fqdn, ".")

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "todo_frontend" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.todo_frontend.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.todo.id]
}

# DNS zone data source (if custom domain is enabled)
data "azurerm_dns_zone" "this" {
  count               = var.enable_custom_domain ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
}

# Local values for generating consistent resource names
locals {
  id = var.unique_id
}

# Validation: Ensure DNS zone variables are provided when needed
locals {
  validation_dns_zone_name = var.enable_custom_domain && var.dns_zone_name == null ? tobool("dns_zone_name is required when enable_custom_domain is true") : true
  validation_dns_zone_rg   = var.enable_custom_domain && var.dns_zone_resource_group_name == null ? tobool("dns_zone_resource_group_name is required when enable_custom_domain is true") : true
}

# Azure Front Door Standard Profile
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "fdp-todo-${local.id}"
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
}

# Azure Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "fde-todo-${local.id}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

# Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "og-storage-${local.id}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  load_balancing {}

  health_probe {
    protocol            = var.health_probe_protocol
    interval_in_seconds = var.health_probe_interval
    path                = var.health_probe_path
    request_type        = var.health_probe_request_type
  }
}

# Origin (Storage Static Website)
resource "azurerm_cdn_frontdoor_origin" "this" {
  name                          = "origin-storage-${local.id}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                       = var.origin_enabled

  certificate_name_check_enabled = var.certificate_name_check_enabled
  host_name                      = var.origin_host_name
  origin_host_header             = var.origin_host_header

  http_port  = var.http_port
  https_port = var.https_port

  priority = var.origin_priority
  weight   = var.origin_weight
}

# Custom Domain (if enabled)
resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  count                    = var.enable_custom_domain ? 1 : 0
  name                     = "cdom-${local.id}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  dns_zone_id              = data.azurerm_dns_zone.this[0].id
  host_name                = var.custom_domain_host_name != null ? var.custom_domain_host_name : trimsuffix(azurerm_dns_cname_record.frontdoor_cname[0].fqdn, ".")

  tls {
    certificate_type    = var.tls_certificate_type
    minimum_tls_version = var.tls_minimum_version
  }

  depends_on = [azurerm_dns_cname_record.frontdoor_cname]
}

# Route
resource "azurerm_cdn_frontdoor_route" "this" {
  name                            = "route-all-${local.id}"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.this.id
  supported_protocols             = var.supported_protocols
  https_redirect_enabled          = var.https_redirect_enabled
  patterns_to_match               = var.patterns_to_match
  forwarding_protocol             = var.forwarding_protocol
  link_to_default_domain          = var.link_to_default_domain
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.this.id]
  cdn_frontdoor_custom_domain_ids = var.enable_custom_domain ? [azurerm_cdn_frontdoor_custom_domain.this[0].id] : []

  cache {
    query_string_caching_behavior = var.cache_query_string_caching_behavior
  }
}

# Custom Domain Association (if custom domain is enabled)
resource "azurerm_cdn_frontdoor_custom_domain_association" "this" {
  count                          = var.enable_custom_domain ? 1 : 0
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.this[0].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.this.id]
}

# CNAME record for Front Door endpoint (if custom domain is enabled)
resource "azurerm_dns_cname_record" "frontdoor_cname" {
  count               = var.enable_custom_domain ? 1 : 0
  zone_name           = data.azurerm_dns_zone.this[0].name
  resource_group_name = data.azurerm_dns_zone.this[0].resource_group_name
  name                = local.id
  ttl                 = var.cname_record_ttl
  record              = azurerm_cdn_frontdoor_endpoint.this.host_name
}

# DNS TXT record for custom domain validation (if custom domain is enabled)
resource "azurerm_dns_txt_record" "frontdoor_validation" {
  count               = var.enable_custom_domain && var.create_validation_record ? 1 : 0
  zone_name           = data.azurerm_dns_zone.this[0].name
  resource_group_name = data.azurerm_dns_zone.this[0].resource_group_name
  name                = "_dnsauth.${local.id}"
  ttl                 = var.dns_validation_record_ttl

  record {
    value = azurerm_cdn_frontdoor_custom_domain.this[0].validation_token
  }
}
output "frontdoor_profile_id" {
  description = "ID of the Azure Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "frontdoor_profile_name" {
  description = "Name of the Azure Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.name
}

output "frontdoor_endpoint_id" {
  description = "ID of the Azure Front Door endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.this.id
}

output "frontdoor_endpoint_host_name" {
  description = "Host name of the Azure Front Door endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "origin_group_id" {
  description = "ID of the origin group"
  value       = azurerm_cdn_frontdoor_origin_group.this.id
}

output "origin_id" {
  description = "ID of the origin"
  value       = azurerm_cdn_frontdoor_origin.this.id
}

output "route_id" {
  description = "ID of the Front Door route"
  value       = azurerm_cdn_frontdoor_route.this.id
}

output "custom_domain_id" {
  description = "ID of the custom domain (if created)"
  value       = var.enable_custom_domain ? azurerm_cdn_frontdoor_custom_domain.this[0].id : null
}

output "custom_domain_validation_token" {
  description = "Validation token for the custom domain (if created)"
  value       = var.enable_custom_domain ? azurerm_cdn_frontdoor_custom_domain.this[0].validation_token : null
  sensitive   = true
}

output "cname_record_fqdn" {
  description = "FQDN of the CNAME record (if created)"
  value       = var.enable_custom_domain ? azurerm_dns_cname_record.frontdoor_cname[0].fqdn : null
}

output "validation_record_id" {
  description = "ID of the DNS validation TXT record (if created)"
  value       = var.enable_custom_domain && var.create_validation_record ? azurerm_dns_txt_record.frontdoor_validation[0].id : null
}

output "dns_zone_id" {
  description = "ID of the DNS zone (if DNS features are used)"
  value       = var.enable_custom_domain ? data.azurerm_dns_zone.this[0].id : null
}

output "dns_zone_name" {
  description = "Name of the DNS zone (if DNS features are used)"
  value       = var.enable_custom_domain ? data.azurerm_dns_zone.this[0].name : null
}
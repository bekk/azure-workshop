data "azurerm_dns_zone" "cloudlabs_azure_no" {
  name                = "cloudlabs-azure.no"
  resource_group_name = "workshop-admin"
}

# API (App Service) CNAME
resource "azurerm_dns_cname_record" "todo-api" {
  zone_name           = data.azurerm_dns_zone.cloudlabs_azure_no.name
  resource_group_name = data.azurerm_dns_zone.cloudlabs_azure_no.resource_group_name

  ttl    = 60
  name   = "api.${local.id}"
  record = azurerm_linux_web_app.todo.default_hostname
}

# Front Door (static site) CNAME
resource "azurerm_dns_cname_record" "todo_cdn" {
  zone_name           = data.azurerm_dns_zone.cloudlabs_azure_no.name
  resource_group_name = data.azurerm_dns_zone.cloudlabs_azure_no.resource_group_name

  ttl    = 60
  name   = "${local.id}"
  record = azurerm_cdn_frontdoor_endpoint.todo_frontdoor.host_name
}

# TXT record for Front Door custom domain validation (Managed Certificate)
# Host: _dnsauth.<subdomain>; Value: token from Front Door custom domain validation blade
resource "azurerm_dns_txt_record" "frontdoor_validation" {
  zone_name           = data.azurerm_dns_zone.cloudlabs_azure_no.name
  resource_group_name = data.azurerm_dns_zone.cloudlabs_azure_no.resource_group_name
  name                = "_dnsauth.${local.id}"
  ttl                 = 60

  record {
    value = azurerm_cdn_frontdoor_custom_domain.todo_frontend.validation_token
  }
}

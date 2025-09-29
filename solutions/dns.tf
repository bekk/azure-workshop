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





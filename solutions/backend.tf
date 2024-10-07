resource "azurerm_service_plan" "todo" {
  name = "sp-todo-${local.id}"

  resource_group_name = azurerm_resource_group.todo.name
  location            = azurerm_resource_group.todo.location

  sku_name = "B1"
  os_type  = "Linux"
}


resource "azurerm_linux_web_app" "todo" {
  name = "app-todo-${local.id}"

  resource_group_name = azurerm_resource_group.todo.name
  location            = azurerm_resource_group.todo.location

  # Note: We're referencing the previously created app service plan 
  service_plan_id     = azurerm_service_plan.todo.id

  https_only = false


  site_config {
    application_stack {
      docker_image_name   = "bekk/k6-workshop-todo-backend:latest"
      docker_registry_url = "https://ghcr.io"
    }
  }

  app_settings = {
    # The connection string format is set by the database connection manager and will be different for different apps
    DATABASE_URL = "sqlserver://${azurerm_mssql_server.todo.fully_qualified_domain_name}:1433;database=${azurerm_mssql_database.todo.name};user=${azurerm_mssql_server.todo.administrator_login};password=${random_password.sql_server_admin_password.result};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30"
  }
}

resource "azurerm_app_service_custom_hostname_binding" "todo-api" {
  hostname = "${azurerm_dns_cname_record.todo-api.name}.${data.azurerm_dns_zone.cloudlabs_azure_no.name}"
                                                                                                          
  resource_group_name = azurerm_resource_group.todo.name
  app_service_name    = azurerm_linux_web_app.todo.name
}

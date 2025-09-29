resource "random_password" "sql_server_admin_password" {
  length  = 24
  special = false
}

resource "azurerm_mssql_server" "todo" {
  # Name, resource group and location
  name                = "sql-todo-${local.id}"
  resource_group_name = azurerm_resource_group.todo.name
  location            = azurerm_resource_group.todo.location

  # The SQL server version
  version = "12.0"

  # The (unsecure) administrator username and password
  administrator_login          = "unsecure-admin"
  administrator_login_password = random_password.sql_server_admin_password.result

  # The Entra ID (Azure AD) based administrator setup
  azuread_administrator {
    # Setting this to true will disable the administrator password-based login
    azuread_authentication_only = false
    # CHANGE THESE
    login_username = "okpedersen"
    object_id      = "03d6f6f9-723f-42e6-b843-38ab6e8dbbd7"
  }

  # Recommended security setting
  minimum_tls_version = "1.2"
  # Is not enough to open the database to the public internet (despite the
  # name), but lets us configure firewall rules in a later step
  public_network_access_enabled = true
}

resource "azurerm_mssql_database" "todo" {
  name      = "db-todo"
  server_id = azurerm_mssql_server.todo.id
  sku_name  = "Basic"
}


resource "azurerm_mssql_firewall_rule" "todo" {
  name             = "All IPv4 addresses"
  server_id        = azurerm_mssql_server.todo.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

locals {
  id = "okp456"
}

resource "azurerm_resource_group" "todo" {
  name     = "rg-todo-${local.id}"
  location = "West Europe"
}

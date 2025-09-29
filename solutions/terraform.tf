terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.117.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}

provider "azurerm" {
  features {}

  # iac-workshop
  subscription_id = "4922867b-a15c-40aa-b9be-dfdf2782cbf7"
}

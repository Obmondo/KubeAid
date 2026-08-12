# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      version = "~> 3.100"
    }

    kubernetes = {
      version = ">= 1.22.6"
    }

    external = {
      version = ">=1.1.0"
    }

    argocd = {
      source = "oboukili/argocd"
      version = "6.0.3"
    }
  }
}

# subscription_id will change based on which subscription VM will be added to
provider "azurerm" {
    features {}
}

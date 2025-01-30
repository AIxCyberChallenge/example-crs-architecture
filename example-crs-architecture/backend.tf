terraform {
  backend "azurerm" {
    resource_group_name  = "example-tfstate-rg"
    storage_account_name = "examplestorageaccountname"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

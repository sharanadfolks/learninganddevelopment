resource "azurerm_resource_group" "rg" {
  name       = "container_registry_rg_2"
  location   = "eastus"
  tags       = {
    Creator  = "Sharan"
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "sharancontainerregistry"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  tags       = {
    Creator  = "Sharan"
  }
}

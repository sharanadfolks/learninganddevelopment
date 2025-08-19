resource "azurerm_resource_group" "rg" {
  name     = "task-2-rg"
  location = "East US"
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "task-2-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags     = var.tags
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "backend_subnet" {
  name                 = "backendsubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "backend_nsg" {
  name                = "nsg-backend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
  security_rule {
    name                       = "Allow_AppGateway_HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.0.1.0/24"  
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }
  security_rule {
  name                       = "Allow-RDP"
  priority                   = 150
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_address_prefix = "*"
  destination_port_range     = "3389"
}

  /*security_rule {
    name                       = "Deny_Internet_Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }*/

}


resource "azurerm_subnet_network_security_group_association" "backend_assoc" {
  subnet_id                 = azurerm_subnet.backend_subnet.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}

resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "nsg-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "GatewayManager"  
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "65200-65535"
  }
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "appgw" {
  name                = "task-2-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    name     = "Standard_v2"   
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ipcfg"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "frontendPort80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "backendHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "health-probe"
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "listener-http"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "frontendPort80"
    protocol                       = "Http"
  }

  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/"
    interval            = 30
    timeout             = 120
    unhealthy_threshold = 3
    pick_host_name_from_backend_http_settings = true
  }

  request_routing_rule {
    name                       = "rule-http"
    rule_type                  = "Basic"
    http_listener_name         = "listener-http"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "backendHttpSettings"
    priority                   = 100
   
  }
  tags       = var.tags
}

resource "azurerm_storage_account" "vmss_scripts" {
  name                     = "sharanvmssscripts"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.vmss_scripts.id
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "install_script" {
  name                   = "install-iis.ps1"
  storage_account_name   = azurerm_storage_account.vmss_scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "./scripts/install-iis.ps1"
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "task2vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B2ms"
  instances           = 2

  admin_username      = "azureadmin"
  admin_password      = "welcome@123" 

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = 127
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "ipconfig"
      primary                                = true
      subnet_id                              = azurerm_subnet.backend_subnet.id
      application_gateway_backend_address_pool_ids = [
        one(azurerm_application_gateway.appgw.backend_address_pool[*].id)
      ]
    }
  }
  tags = var.tags

  depends_on = [
    azurerm_application_gateway.appgw
  ]
}



resource "azurerm_virtual_machine_scale_set_extension" "vmss_iis" {
  name                         = "iis-install"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.vmss.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"

  settings = <<SETTINGS
{
    "fileUris": ["https://${azurerm_storage_account.vmss_scripts.name}.blob.core.windows.net/scripts/install-iis.ps1"],
    "commandToExecute": "powershell -ExecutionPolicy Bypass -File .\\install-iis.ps1"
}
SETTINGS

}
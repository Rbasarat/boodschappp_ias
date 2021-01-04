# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "boodschappp"
  location = var.region
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
}

# Scrapers vm
resource "azurerm_subnet" "scraper_vm_subnet" {
  name                 = "scraper-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "scraper_vm_public_ip" {
  name                = "scraper-vm-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"

  tags = {
    service = "boodschappp_scrapers"
  }
}

resource "azurerm_network_security_group" "scraper_vm_nsg" {
  name                = "scraper-vm-nsg"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    service = "boodschappp_scrapers"
  }
}

resource "azurerm_network_interface" "scraper_vm_nic" {
  name                = "scraper-vm-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "scraper-vm-nic-config"
    subnet_id                     = azurerm_subnet.scraper_vm_subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.scraper_vm_public_ip.id
  }

  tags = {
    service = "boodschappp_scrapers"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "scraper_vm_nic_nsg" {
  network_interface_id      = azurerm_network_interface.scraper_vm_nic.id
  network_security_group_id = azurerm_network_security_group.scraper_vm_nsg.id
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "scraper_vm" {
  name                  = "scraper-vm"
  location              = var.region
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.scraper_vm_nic.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "scraper-vm"
  admin_username                  = var.scraper_vm_admin_username
  disable_password_authentication = true

  # #todo.
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  tags = {
    service = "boodschappp_scrapers"
  }
}

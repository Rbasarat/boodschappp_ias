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
  subscription_id = var.az_subscription_id
  client_id       = var.az_client_id
  client_secret   = var.client_secret
  tenant_id       = var.az_tenant_id
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
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.private_ip_rasjaad
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "port80"
    priority                   = 1011
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.private_ip_rasjaad
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
    private_ip_address_allocation = "Dynamic"
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
  size                  = "Standard_B1s"

  os_disk {
    name                 = "scraper-vm-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
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

  admin_ssh_key {
    username   = var.scraper_vm_admin_username
    public_key = var.ssh_public_key
  }

  tags = {
    service = "boodschappp_scrapers"
  }
}

# Storage account
resource "azurerm_storage_account" "static-content-storage" {
  name                     = "boodschappp"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  allow_blob_public_access = true

}
#cdn profile
resource "azurerm_cdn_profile" "cdn-website" {
  name                = "static-cdn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  sku                 = "Standard_Akamai"
}
# cdn endpoint for storage
resource "azurerm_cdn_endpoint" "static-boodschappp-nl" {
  name                = "boodschappp-static"
  profile_name        = azurerm_cdn_profile.cdn-website.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region

  origin {
    name      = "boodschappp-nl"
    host_name = "boodschappp.blob.core.windows.net"
  }
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}
variable "joy" {
    type = string
}

variable "location" {
    type = string
  
}

variable "vm_name" {
  type = list(string)
}


resource "azurerm_resource_group" "johit" {
    name     = "${var.joy}"
    location = "${var.location}"
    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "${var.joy}-myvnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.location}"
    resource_group_name = azurerm_resource_group.johit.name

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "${var.joy}--subnet"
    resource_group_name  = azurerm_resource_group.johit.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.2.0/24"]
}
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "${var.joy}--mypublicip"
    location                     = "${var.location}"
    resource_group_name          = azurerm_resource_group.johit.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "${var.joy}"
    location            = "${var.location}"
    resource_group_name = azurerm_resource_group.johit.name

    security_rule {
        name                       = "RDP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_network_interface" "myterraformnic" {
       for_each = toset(var.vm_name)
    name                = each.value
    location                    = "${var.location}"
    resource_group_name         = azurerm_resource_group.johit.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.johit.name
    }

    byte_length = 8
}
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.johit.name
    location                    = "${var.location}"
    account_replication_type    = "LRS"
    account_tier                = "Standard"

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_windows_virtual_machine" "example" {
    for_each = toset(var.vm_name)
  name                = each.value
  resource_group_name = azurerm_resource_group.johit.name
  location            = azurerm_resource_group.johit.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    
    azurerm_network_interface.myterraformnic[each.key].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

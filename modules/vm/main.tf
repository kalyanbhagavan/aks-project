# Network Security Group for jumpbox
resource "azurerm_network_security_group" "jumpbox" {
  name                = "${var.vm_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

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

  security_rule {
    name                       = "RDP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

# Public IP for jumpbox
resource "azurerm_public_ip" "jumpbox" {
  name                = "${var.vm_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

# Network Interface for jumpbox
resource "azurerm_network_interface" "jumpbox" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "jumpbox" {
  network_interface_id      = azurerm_network_interface.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Disable password authentication and use SSH keys
  disable_password_authentication = false
  admin_password                  = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.jumpbox.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Install necessary tools via custom script
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
    admin_username = var.admin_username
  }))

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
    role        = "jumpbox"
  }

  # Assign user assigned identity to the VM
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jumpbox.id]
  }
}

# Managed Identity for the VM
resource "azurerm_user_assigned_identity" "jumpbox" {
  location            = var.location
  name                = "${var.vm_name}-identity"
  resource_group_name = var.resource_group_name

  tags = {
    environment = "production"
    project     = "aks-demo-challenge"
  }
}

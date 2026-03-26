output "vm_name" {
  description = "Name of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.main.name
}

output "public_ip_address" {
  description = "Public IP address of the build VM. Use for SSH, SonarQube (:9000), and Nexus (:8081) access."
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_id" {
  description = "Resource ID of the Linux virtual machine."
  value       = azurerm_linux_virtual_machine.main.id
}

output "private_ip_address" {
  description = "Private IP address assigned to the VM NIC. Connect via Azure Bastion."
  value       = azurerm_network_interface.main.private_ip_address
}

output "identity_object_id" {
  description = "Object ID of the VM's system-assigned managed identity. Used for Key Vault access policy."
  value       = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

output "nic_id" {
  description = "Resource ID of the VM's network interface."
  value       = azurerm_network_interface.main.id
}

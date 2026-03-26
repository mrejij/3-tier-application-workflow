output "bastion_name" {
  description = "Name of the Azure Bastion host."
  value       = azurerm_bastion_host.main.name
}

output "bastion_id" {
  description = "Resource ID of the Azure Bastion host."
  value       = azurerm_bastion_host.main.id
}

output "public_ip_address" {
  description = "Public IP address assigned to the Bastion host."
  value       = azurerm_public_ip.bastion.ip_address
}

output "public_ip_id" {
  description = "Resource ID of the Bastion public IP."
  value       = azurerm_public_ip.bastion.id
}

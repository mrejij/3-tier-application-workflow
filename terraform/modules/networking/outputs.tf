output "vnet_name"          { value = azurerm_virtual_network.main.name }
output "vnet_id"            { value = azurerm_virtual_network.main.id }
output "aks_subnet_id"      { value = azurerm_subnet.aks.id }
output "vm_subnet_id"       { value = azurerm_subnet.vm.id }
output "bastion_subnet_id"  { value = azurerm_subnet.bastion.id }
output "sql_subnet_id"      { value = azurerm_subnet.sql.id }
output "aks_subnet_cidr"    { value = azurerm_subnet.aks.address_prefixes[0] }
output "vm_subnet_cidr"     { value = azurerm_subnet.vm.address_prefixes[0] }

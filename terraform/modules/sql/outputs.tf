output "server_id" {
  description = "Resource ID of the Azure SQL logical server."
  value       = azurerm_mssql_server.main.id
}

output "server_name" {
  description = "Name of the Azure SQL logical server."
  value       = azurerm_mssql_server.main.name
}

output "server_fqdn" {
  description = "Fully qualified domain name of the SQL server. Use in connection strings."
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "database_name" {
  description = "Name of the SQL database."
  value       = azurerm_mssql_database.main.name
}

output "database_id" {
  description = "Resource ID of the SQL database."
  value       = azurerm_mssql_database.main.id
}

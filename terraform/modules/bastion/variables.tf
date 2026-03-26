variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "project" {
  type        = string
  description = "Project name used in resource naming."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)."
}

variable "subnet_id" {
  type        = string
  description = "Resource ID of AzureBastionSubnet (/27 minimum CIDR required)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags to apply to all resources in this module."
}

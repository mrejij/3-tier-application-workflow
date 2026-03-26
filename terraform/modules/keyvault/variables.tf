variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "suffix" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "current_user_object_id" {
  type = string
}

variable "vm_ssh_private_key" {
  type      = string
  sensitive = true
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

variable "sql_admin_username" {
  type = string
}

variable "tags" {
  type = map(string)
}

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

variable "node_count" {
  type    = number
  default = 1
}

variable "node_vm_size" {
  type = string
}

variable "os_disk_size_gb" {
  type    = number
  default = 32
}

variable "subnet_id" {
  type = string
}

variable "acr_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

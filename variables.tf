variable "scraper_vm_admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "region" {
  type    = string
  default = "West Europe"
}

variable "az_subscription_id" {
  type = string
}

variable "az_client_id" {
  type = string
}

variable "az_tenant_id" {
  type = string
}

variable "client_secret" {
  type = string
}

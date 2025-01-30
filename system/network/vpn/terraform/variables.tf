variable "linode_api_token" {
  description = "API token for Linode"
  type        = string
}

variable "server_name" {
  description = "Name for the Linode server"
  type        = string
}

variable "region" {
  description = "Region for the Linode server"
  type        = string
  default     = "us-east"
}

variable "instance_type" {
  description = "Linode instance type"
  type        = string
  default     = "g6-nanode-1"
}

variable "root_password" {
  description = "Root password for the Linode server"
  type        = string
}
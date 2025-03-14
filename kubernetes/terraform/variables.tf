
variable "network_gateway" {
  description = "ip address of proxmox network gateway"
  type = string
}

variable proxmox_ssh_private_key {
  description = "Path to the SSH private key file"
  type        = string
}

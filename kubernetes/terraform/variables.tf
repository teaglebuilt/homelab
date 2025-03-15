variable "control_plane_ip" {
  description = "ip address of virtual control plane"
  type = string
}

variable "network_gateway" {
  description = "ip address of proxmox network gateway"
  type = string
}

variable proxmox_ssh_private_key {
  description = "Path to the SSH private key file"
  type        = string
}


variable "k8s_api_server_ip" {
  description = "ip address of k8s api server"
  type = string
}

variable "master_node_ip" {
  description = "ip address of master node"
  type = string
}

variable "worker_one_node_ip" {
  description = "ip address of worker node"
  type = string
}

variable "worker_two_node_ip" {
  description = "ip address of worker node"
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

variable proxmox_node_one_api_token {
  description = "api token for proxmox node one"
  type        = string
}

variable proxmox_node_two_api_token {
  description = "api token for proxmox node two"
  type        = string
}

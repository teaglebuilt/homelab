variable "proxmox_endpoint" {
  description = "Proxmox endpoint"
  type = string
}

variable "proxmox_insecure" {
  description = "Proxmox insecure"
  type = bool
}

variable "k8s_api_server_ip" {
  description = "ip address of k8s api server"
  type = string
}

variable "master_node_ip" {
  description = "ip address of master node"
  type = string
}

variable "worker_node_ip" {
  description = "ip address of worker node"
  type = string
}

variable "network_gateway" {
  description = "ip address of proxmox network gateway"
  type = string
}
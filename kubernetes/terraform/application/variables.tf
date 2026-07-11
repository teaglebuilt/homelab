variable "app_k8s_api_server_ip" {
  description = "k8s API server / cluster endpoint IP for application (on 192.168.2.0/24)"
  type        = string
}

variable "app_master_node_ip" {
  description = "controlplane node IP for application"
  type        = string
}

variable "app_worker_one_node_ip" {
  description = "worker node IP for application"
  type        = string
}

# variable "app_worker_two_node_ip" {
#   description = "worker node IP for application"
#   type        = string
# }

variable "network_gateway" {
  description = "network gateway (shared 192.168.2.0/24 gateway)"
  type        = string
}

variable "graylog_ip" {
  description = "central Graylog endpoint for node logging"
  type        = string
}

variable "proxmox_ssh_private_key" {
  description = "Path to the SSH private key file for the pve Proxmox host"
  type        = string
}

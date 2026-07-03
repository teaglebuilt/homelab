# administration cluster (pve1) inputs. Provide real values via TF_VAR_* env or a
# terraform.tfvars before applying — nothing here is hardcoded to an IP.

variable "admin_k8s_api_server_ip" {
  description = "k8s API server / cluster endpoint IP for administration (on 192.168.2.0/24)"
  type        = string
}

variable "admin_master_node_ip" {
  description = "controlplane node IP for administration"
  type        = string
}

variable "admin_worker_node_ip" {
  description = "worker node IP for administration"
  type        = string
}

variable "network_gateway" {
  description = "network gateway (shared 192.168.2.0/24 gateway)"
  type        = string
}

variable "graylog_ip" {
  description = "central Graylog endpoint for node logging"
  type        = string
}

variable "proxmox_ssh_private_key" {
  description = "Path to the SSH private key file for the pve1 Proxmox host"
  type        = string
}

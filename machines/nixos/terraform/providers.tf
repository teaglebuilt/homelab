locals {
  proxmox_ssh_pem = startswith(trimspace(var.proxmox_ssh_private_key), "-----BEGIN") ? trimspace(var.proxmox_ssh_private_key) : file(var.proxmox_ssh_private_key)
}

provider "proxmox" {
  endpoint = trimspace(var.proxmox_endpoint) != "" ? trimspace(var.proxmox_endpoint) : null
  insecure = var.proxmox_api_insecure_tls
  min_tls  = var.proxmox_min_tls
  tmp_dir  = trimspace(var.proxmox_tmp_dir)

  ssh {
    agent       = false
    username    = trimspace(var.proxmox_ssh_username)
    private_key = local.proxmox_ssh_pem

    node_address_source = trimspace(var.proxmox_ssh_node_address_source)
  }
}

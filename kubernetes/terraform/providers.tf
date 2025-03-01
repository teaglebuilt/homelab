terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    talos = {
      source  = "siderolabs/talos"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

provider "proxmox" {
  ssh {
    agent       = false
    private_key = var.proxmox_ssh_private_key
  }
}
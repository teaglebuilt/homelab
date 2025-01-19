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
  # provider configuration if needed
}
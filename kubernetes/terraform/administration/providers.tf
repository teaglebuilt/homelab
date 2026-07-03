terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    talos = {
      source = "siderolabs/talos"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Standalone root, separate state from mlops. Point the Proxmox endpoint/token at
# pve1 via env (PROXMOX_VE_ENDPOINT / PROXMOX_VE_API_TOKEN or PROXMOX_VE_USERNAME
# + PROXMOX_VE_PASSWORD) when running plan/apply for this cluster.
provider "proxmox" {
  ssh {
    agent       = false
    private_key = var.proxmox_ssh_private_key
  }
}

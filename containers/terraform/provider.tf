provider "proxmox" {
  ssh {
    agent       = false
    private_key = var.proxmox_ssh_private_key
  }
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_server_ip}:8006"

  ssh {
    agent       = false
    private_key = var.proxmox_ssh_private_key
  }
}

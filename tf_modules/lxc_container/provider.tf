
provider "proxmox" {
  endpoint = "https://${var.proxmox_server_ip}:8006"
  username = var.user
  password = var.password
  insecure = true
  ssh {
    agent       = false
    private_key = var.private_key
  }
}
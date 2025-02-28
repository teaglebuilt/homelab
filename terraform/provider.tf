
provider "proxmox" {
  endpoint = "https://${var.proxmox_server_ip}:8006"
  username = var.proxmox_username
  password = var.proxmox_password
  api_token = var.proxmox_api_token

  ssh {
    agent       = false
    private_key = file(var.proxmox_ssh_private_key)
  }
}
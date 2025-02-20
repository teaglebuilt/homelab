
provider "proxmox" {
  endpoint = "https://192.168.2.100:8006"
  username = "root@pam"
  password = "cosmo"
  insecure = true
  ssh {
    agent       = false
    private_key = file("~/.ssh/terraform_pve1")
  }
}
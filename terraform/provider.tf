
provider "proxmox" {
  insecure = true
  ssh {
    agent       = false
    private_key = file("~/.ssh/terraform_proxmox")
  }
}
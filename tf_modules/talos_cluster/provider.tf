provider "proxmox" {
  endpoint = "https://${var.proxmox_server_ip}:8006"
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true
  ssh {
    agent       = false
    private_key = var.proxmox_ssh_private_key
  }
}

provider "kubernetes" {
  host = module.talos.kube_config.kubernetes_client_configuration.host
  client_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
  client_key = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
}
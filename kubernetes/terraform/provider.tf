provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure
  # api_token = var.proxmox.api_token
  # ssh {
  #   agent    = true
  #   username = var.proxmox.username
  # }
}

provider "kubernetes" {
  host = module.talos.kube_config.kubernetes_client_configuration.host
  client_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
  client_key = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
}
# provider "argocd" {
#   grpc_web    = true
#   server_addr = "argocd.${data.infisical_secrets.cluster.secrets["global_fqdn"].value}"
#   username    = "admin"
#   password    = data.infisical_secrets.cluster.secrets["argocd_password"].value
# }

provider "proxmox" {
  endpoint = var.PROXMOX_VE_ENDPOINT
  insecure = true
}
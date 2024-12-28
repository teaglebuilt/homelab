provider "argocd" {
  grpc_web    = true
  server_addr = "argocd.${data.infisical_secrets.cluster.secrets["global_fqdn"].value}"
  username    = "admin"
  password    = data.infisical_secrets.cluster.secrets["argocd_password"].value
}

provider "proxmox" {
  pm_api_url      = "https://your-proxmox-host:8006/api2/json"
  pm_user         = "root@pam"
  pm_password     = "yourpassword"
  pm_tls_insecure = true
}
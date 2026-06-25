terraform {
  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "~> 1.0"
    }
  }
}

provider "portainer" {
  endpoint        = "http://${var.portainer_ip}:9000"
  api_key         = var.portainer_api_key
  skip_ssl_verify = true
}

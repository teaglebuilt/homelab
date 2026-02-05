terraform {
  required_providers {
    unifi = {
      source  = "resnickio/unifi"
      version = "~> 0.1"
    }
  }
}

provider "unifi" {
  base_url = var.unifi_base_url
  api_key  = var.unifi_api_key
  insecure = true
  site     = "default"
}

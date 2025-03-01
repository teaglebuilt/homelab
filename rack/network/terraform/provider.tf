terraform {
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.28.0"
    }
  }
}

provider "unifi" {
  username = var.unifi_username
  password = var.unifi_password
  api_url  = "https://unifi-controller:8443"
  site     = "default"
  allow_insecure = true  # Use only if your controller has a self-signed cert
}

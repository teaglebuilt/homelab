resource "portainer_stack" "downloads" {
  name            = "downloads"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.portainer_endpoint_id

  stack_file_content = file("${path.module}/../compose.yaml")

  env {
    name  = "DOWNLOADS_IP"
    value = var.downloads_ip
  }

  env {
    name  = "SUBNET_CIDR"
    value = var.subnet_cidr
  }

  env {
    name  = "GATEWAY"
    value = var.network_gateway
  }

  env {
    name  = "VPN_SERVICE_PROVIDER"
    value = var.vpn_service_provider
  }

  env {
    name  = "WIREGUARD_PRIVATE_KEY"
    value = var.wireguard_private_key
  }

  env {
    name  = "SERVER_COUNTRIES"
    value = var.server_countries
  }

  env {
    name  = "VPN_PORT_FORWARDING"
    value = var.vpn_port_forwarding
  }
}

variable "portainer_ip" {
  description = "IP address of the Portainer instance"
  type        = string
}

variable "portainer_api_key" {
  description = "Portainer API key for authentication"
  type        = string
  sensitive   = true
}

variable "portainer_endpoint_id" {
  description = "Portainer environment/endpoint ID (default local environment is 1)"
  type        = number
  default     = 3
}

variable "downloads_ip" {
  description = "Static IP for gluetun on the downloads macvlan network"
  type        = string
  default     = "10.0.8.10"
}

variable "network_gateway" {
  description = "Gateway for the downloads network"
  type        = string
  default     = "10.0.8.1"
}

variable "subnet_cidr" {
  description = "Subnet CIDR for the downloads macvlan network"
  type        = string
  default     = "10.0.8.0/24"
}

variable "vpn_service_provider" {
  description = "Gluetun VPN provider name"
  type        = string
  default     = "protonvpn"
}

variable "wireguard_private_key" {
  description = "WireGuard private key"
  type        = string
  sensitive   = true
}

variable "server_countries" {
  description = "VPN server countries"
  type        = string
  default     = "Netherlands"
}

variable "vpn_port_forwarding" {
  description = "Enable VPN port forwarding"
  type        = string
  default     = "on"
}

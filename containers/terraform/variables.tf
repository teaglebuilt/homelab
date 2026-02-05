variable "proxmox_server_ip" {
  description = "ip address of proxmox network gateway"
  type = string
}

variable proxmox_ssh_public_key {
  description = "Path to the SSH public key file"
  type        = string
}

variable proxmox_ssh_private_key {
  description = "Path to the SSH private key file"
  type        = string
}

variable "network_gateway" {
  description = "Default network gateway (UDM Pro)"
  type    = string
  default = "192.168.1.1"
}

variable "portainer_ip" {
  description = "ip address of proxmox network gateway"
  type = string
}

variable "portainer_password" {
  description = "ip address of proxmox network gateway"
  type = string
}

variable "media_ip" {
  description = "Static IP for eth1 on VLAN 30 (Media)"
  type        = string
  default     = "10.0.30.10"
}

variable "downloads_ip" {
  description = "Static IP for eth1 on VLAN 8 (Downloads)"
  type        = string
  default     = "192.168.8.2"
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

variable "wireguard_public_key" {
  description = "WireGuard server public key"
  type        = string
  sensitive   = true
}

variable "wireguard_addresses" {
  description = "WireGuard tunnel address"
  type        = string
}

variable "wireguard_endpoint_ip" {
  description = "WireGuard server endpoint IP"
  type        = string
}

variable "wireguard_endpoint_port" {
  description = "WireGuard server endpoint port"
  type        = string
  default     = "51820"
}

variable "vpn_port_forwarding" {
  description = "Enable VPN port forwarding for seeding"
  type        = string
  default     = "on"
}

variable "vpn_port_forwarding_provider" {
  description = "VPN provider name for port forwarding"
  type        = string
  default     = ""
}

variable "host_sre_storage_path" {
  description = "Host path for SRE storage bind mount"
  type        = string
  default     = "/mnt/sre_storage"
}

variable "host_downloads_storage_path" {
  description = "Host path for downloads storage bind mount"
  type        = string
  default     = "/mnt/downloads_storage"
}

variable "host_media_storage_path" {
  description = "Host path for media storage bind mount"
  type        = string
  default     = "/mnt/media_storage"
}

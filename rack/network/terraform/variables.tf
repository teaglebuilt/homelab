# ──────────────────────────────────────────────
# Provider Configuration Variables
# ──────────────────────────────────────────────

variable "unifi_api_key" {
  type        = string
  sensitive   = true
  description = "UniFi Controller API key"
}

variable "unifi_base_url" {
  type        = string
  description = "UniFi Controller base URL (e.g., https://IP_ADDRESS)"
}

# ──────────────────────────────────────────────
# Network Infrastructure Variables
# ──────────────────────────────────────────────

variable "vlans" {
  type = map(object({
    name       = string
    vlan_id    = number
    subnet     = string
    dhcp_start = string
    dhcp_stop  = string
    purpose    = string
  }))
  description = "VLAN network configuration including subnets and DHCP ranges"
}

# ──────────────────────────────────────────────
# Service IP Addresses
# ──────────────────────────────────────────────

variable "media_server_ip" {
  type        = string
  description = "IP address of the media server (Plex, Overseerr, Sonarr, Radarr)"
}

variable "downloads_server_ip" {
  type        = string
  description = "IP address of the downloads server (qBittorrent)"
}

# ──────────────────────────────────────────────
# Traffic Management Variables
# ──────────────────────────────────────────────

variable "wan_bandwidth_kbps" {
  type        = number
  description = "WAN bandwidth in Kbps for calculating throttle percentages"
  default     = 1000000 # 1 Gbps in Kbps
}

# ──────────────────────────────────────────────
# WiFi Configuration Variables
# ──────────────────────────────────────────────

variable "wifi_trusted_password" {
  type        = string
  sensitive   = true
  description = "WiFi password for trusted network"
}

variable "wifi_iot_password" {
  type        = string
  sensitive   = true
  description = "WiFi password for IoT network"
}

variable "wifi_guest_password" {
  type        = string
  sensitive   = true
  description = "WiFi password for guest network"
}

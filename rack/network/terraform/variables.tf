# Unifi Controller Authentication
variable "unifi_username" {
  description = "Username for Unifi Controller authentication"
  type        = string
  sensitive   = true
}

variable "unifi_password" {
  description = "Password for Unifi Controller authentication"
  type        = string
  sensitive   = true
}

variable "unifi_api_url" {
  description = "URL for Unifi Controller API"
  type        = string
  default     = "https://unifi-controller:8443"
}

variable "unifi_site" {
  description = "Unifi site to manage"
  type        = string
  default     = "default"
}

# DNS Records
variable "proxmox_node_one" {
  description = "IP address for Proxmox node one"
  type        = string
}

variable "proxmox_node_two" {
  description = "IP address for Proxmox node two"
  type        = string
}

variable "dns_records" {
  description = "Additional DNS host records to create"
  type = map(object({
    name    = string
    address = string
    type    = string
  }))
  default = {}
}

# Network Configuration
variable "networks" {
  description = "Network configurations"
  type = map(object({
    name                = string
    subnet              = string
    vlan_id             = optional(number)
    dhcp_enabled        = optional(bool, true)
    dhcp_start          = optional(string)
    dhcp_stop           = optional(string)
    dhcp_dns            = optional(list(string))
    igmp_snooping       = optional(bool, false)
    multicast_dns       = optional(bool, false)
    ipv6_enabled        = optional(bool, false)
    domain_name         = optional(string)
    network_group       = optional(string)
  }))
  default = {}
}

# Firewall Rules
variable "firewall_rules" {
  description = "Firewall rule configurations"
  type = list(object({
    name                = string
    action              = string
    rule_index          = number
    ruleset             = string
    protocol            = optional(string)
    src_network         = optional(string)
    src_address         = optional(string)
    src_port            = optional(string)
    dst_network         = optional(string)
    dst_address         = optional(string)
    dst_port            = optional(string)
    logging             = optional(bool, false)
    enabled             = optional(bool, true)
  }))
  default = []
}

# WiFi Networks
variable "wifi_ssids" {
  description = "WiFi SSID configurations"
  type = map(object({
    name                   = string
    passphrase            = string
    security              = optional(string, "wpa2")
    network_id            = optional(string)
    user_group_id         = optional(string)
    hide_ssid             = optional(bool, false)
    is_guest              = optional(bool, false)
    multicast_enhance     = optional(bool, false)
    bss_transition        = optional(bool, true)
    uapsd                 = optional(bool, true)
    fast_roaming_enabled  = optional(bool, false)
    pmf_mode              = optional(string, "optional")
    minimum_data_rate_2g  = optional(number)
    minimum_data_rate_5g  = optional(number)
    wlan_bands            = optional(list(string), ["2g", "5g"])
  }))
  default = {}
}

# Port Forwarding
variable "port_forwards" {
  description = "Port forwarding rules"
  type = list(object({
    name            = string
    dst_port        = string
    fwd_ip          = string
    fwd_port        = string
    protocol        = optional(string, "tcp")
    src_ip          = optional(string, "any")
    log             = optional(bool, false)
    enabled         = optional(bool, true)
  }))
  default = []
}

# Static Routes
variable "static_routes" {
  description = "Static route configurations"
  type = map(object({
    name     = string
    network  = string
    distance = number
    next_hop = string
  }))
  default = {}
}

# User Groups
variable "user_groups" {
  description = "User group configurations for bandwidth management"
  type = map(object({
    name              = string
    qos_rate_max_down = optional(number, -1)
    qos_rate_max_up   = optional(number, -1)
  }))
  default = {}
}

# DHCP Options
variable "dhcp_options" {
  description = "DHCP option configurations"
  type = list(object({
    code    = number
    name    = string
    type    = string
    value   = string
  }))
  default = []
}

# Feature Flags
variable "enable_multicast" {
  description = "Enable multicast features globally"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6 features globally"
  type        = bool
  default     = false
}

variable "enable_dpi" {
  description = "Enable Deep Packet Inspection"
  type        = bool
  default     = true
}

variable "enable_ids_ips" {
  description = "Enable Intrusion Detection/Prevention System"
  type        = bool
  default     = false
}

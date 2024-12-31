variable "PROXMOX_VE_ENDPOINT" {
  type = string
}

variable network_base_ip {
  type        = string
  default     = "192.168.2"
}

variable network_start {
  type        = string
  default     = "10"
}

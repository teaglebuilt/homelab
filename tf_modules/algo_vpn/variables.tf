variable "server_ip" {
  description = "The public IP address of the server where AlgoVPN will be provisioned."
  type        = string
}

variable "server_user" {
  description = "The SSH user for accessing the server."
  type        = string
  default     = "algo"
}

variable "private_key_path" {
  description = "Path to the private SSH key for accessing the server."
  type        = string
}

variable "user_name" {
  description = "The VPN user name to be configured in AlgoVPN."
  type        = string
  default     = "vpnuser"
}

variable "wireguard_port" {
  description = "The port for WireGuard VPN connections."
  type        = number
  default     = 51820
}
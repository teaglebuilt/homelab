variable cluster_name {
  type        = string
}

variable "default_gateway" {
  type    = string
  default = "<IP address of your default gateway>"
}

variable "control_plane_ips" {
  type    = list(string)
}

variable "worker_ips" {
  type    = list(string)
}

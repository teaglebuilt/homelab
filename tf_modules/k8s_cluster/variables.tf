variable cluster_name {
  type        = string
}

variable "control_plane_ips" {
  type    = list(string)
}

variable "worker_ips" {
  type    = list(string)
}

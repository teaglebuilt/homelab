variable "name" {}
variable "vmid" {}
variable "node" {}
variable "cores" { default = 4 }
variable "memory" { default = 8192 }
variable "disk_size" { default = "64G" }
variable "storage" { default = "local-lvm" }
variable "bridge" { default = "vmbr0" }
variable "iso" {}
variable "os_type" {}
variable "connection_type" {}
variable "admin_user" {}
variable "admin_password" {}
variable "endpoint" {}
variable "user" {}
variable "password" {}

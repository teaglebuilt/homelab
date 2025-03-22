variable "image" {
  description = "Talos image configuration"
  type = object({
    factory_url = optional(string, "https://factory.talos.dev")
    version   = string
    update_version = optional(string)
    arch = optional(string, "amd64")
    platform = optional(string, "nocloud")
    proxmox_datastore = optional(string, "local")
  })
}

variable "cluster" {
  description = "Cluster configuration"
  type = object({
    name            = string
    endpoint        = string
    gateway         = string
    talos_version   = string
  })
}

variable node_name {
  description = "proxmox node host dns"
  type        = string
}

variable proxmox_host_node {
  description = "proxmox node host dns"
  type        = string
}

variable machine_type {
  description = "proxmox node host dns"
  type        = string
}

variable cpu {
  type = string
}

variable ram_dedicated {
  type = string
}

variable disk_size {
  type = number
}

variable vm_id {
  type = string
}

variable ip {
  type = string
}

variable igpu {
  type        = bool
  description = "description"
}

variable "pci" {
  description = "Configuration for any PCIe device in passthrough mode (GPU)"
  type = object({
    name         = string
    id           = string
    iommu_group  = number
    node         = string
    path         = string
    subsystem_id = string
  })
  default = null
}

variable datastore_id {
  type        = string
  default     = "local-lvm"
  description = "description"
}

variable proxmox_ssh_private_key {
  description = "Path to the SSH private key file"
  type        = string
}

variable api_token {
  type = string
}

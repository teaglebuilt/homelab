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
    proxmox_cluster = string
  })
}

variable "nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    host_node     = string
    machine_type  = string
    datastore_id = optional(string, "local-lvm")
    ip            = string
    vm_id         = number
    cpu           = number
    disk_size     = number
    ram_dedicated = number
    update = optional(bool, false)
    igpu = optional(bool, false)
    pci = optional(object({
      name         = string
      id           = string
      iommu_group  = number
      node         = string
      path         = string
      subsystem_id = string
    }))
  }))
}

variable proxmox_ssh_private_key {
  description = "Path to the SSH private key file"
  type        = string
}
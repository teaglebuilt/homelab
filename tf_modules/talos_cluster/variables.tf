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
    name                = string
    endpoint            = string
    gateway             = string
    talos_version       = string
    kubernetes_version  = string
    proxmox_cluster     = string
    logging_server      = string
    # Pod/Service CIDRs must be non-overlapping across clusters for Cilium ClusterMesh.
    # Defaults match Talos defaults so existing single-cluster behaviour is unchanged.
    pod_subnet          = optional(string, "10.244.0.0/16")
    service_subnet      = optional(string, "10.96.0.0/12")
    # Whether Proxmox verifies the TLS cert when downloading the Talos factory
    # image. Default true. Set false only for a host whose Proxmox Perl HTTP client
    # (LWP) fails verification even though the OS (curl) trusts the cert.
    verify_image_download = optional(bool, true)
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

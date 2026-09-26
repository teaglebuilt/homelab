variable "image" {
  description = "Talos image configuration"
  type = object({
    factory_url = optional(string, "https://factory.talos.dev")
    version   = string
    update_version = optional(string)
    arch = optional(string, "amd64")
    platform = optional(string, "nocloud")
    proxmox_datastore = optional(string, "local")
    # ~750MB GPU-extension images exceed the provider's 600s default.
    download_timeout = optional(number, 3600)
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
    cluster_name        = string
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
    kubelet_reserved = optional(object({
      system_cpu       = optional(string, "200m")
      system_memory    = optional(string, "512Mi")
      system_ephemeral = optional(string, "1Gi")
      kube_cpu         = optional(string, "200m")
      kube_memory      = optional(string, "512Mi")
      kube_ephemeral   = optional(string, "1Gi")
      eviction_memory  = optional(string, "5%")
      eviction_nodefs  = optional(string, "10%")
      eviction_imagefs = optional(string, "10%")
    }), {})
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

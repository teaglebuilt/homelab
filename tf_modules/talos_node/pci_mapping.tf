data "proxmox_virtual_environment_hardware_mapping_pci" "existing" {
  count = var.igpu && var.pci != null ? 1 : 0
  name = var.pci.name
}

resource "proxmox_virtual_environment_hardware_mapping_pci" "pci" {
  count = var.igpu && var.pci != null && (
    try(data.proxmox_virtual_environment_hardware_mapping_pci.existing[0].name, "") == ""
  ) ? 1 : 0

  comment  = var.pci.name
  name     = var.pci.name
  map = [
    {
      comment      = var.pci.name
      id           = var.pci.id
      iommu_group  = var.pci.iommu_group
      node         = var.proxmox_host_node
      path         = var.pci.path
      subsystem_id = var.pci.subsystem_id
    }
  ]
  mediated_devices = false

  lifecycle {
    prevent_destroy = false
  }
}

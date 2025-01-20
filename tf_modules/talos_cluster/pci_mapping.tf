data "proxmox_virtual_environment_hardware_mapping_pci" "existing" {
  for_each = { for k, v in var.nodes : k => v if v.pci != null }
  name     = each.value.pci.name
}

resource "proxmox_virtual_environment_hardware_mapping_pci" "pci" {
  for_each = { 
    for k, v in var.nodes : k => v 
    if v.pci != null && 
    try(data.proxmox_virtual_environment_hardware_mapping_pci.existing[k].name, "") == ""
  }
  
  comment  = each.value.pci.name
  name     = each.value.pci.name
  map = [
    {
      comment      = each.value.pci.name
      id           = each.value.pci.id
      iommu_group  = each.value.pci.iommu_group
      node         = each.value.host_node
      path         = each.value.pci.path
      subsystem_id = each.value.pci.subsystem_id
    }
  ]
  mediated_devices = false

  lifecycle {
    prevent_destroy = true
  }
}
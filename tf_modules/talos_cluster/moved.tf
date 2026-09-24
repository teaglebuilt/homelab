# Rename deprecated bpg/proxmox resource types to their non-deprecated aliases.
# These moved blocks let OpenTofu reconcile old state addresses with new resource
# declarations without destroying or re-creating any infrastructure.

moved {
  from = proxmox_virtual_environment_download_file.this
  to   = proxmox_download_file.this
}

moved {
  from = proxmox_virtual_environment_hardware_mapping_pci.pci
  to   = proxmox_hardware_mapping_pci.pci
}

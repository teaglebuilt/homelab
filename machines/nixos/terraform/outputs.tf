output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.nixos.vm_id
}

output "vm_name" {
  description = "Proxmox guest name."
  value       = proxmox_virtual_environment_vm.nixos.name
}

output "nixos_iso_file_id" {
  description = "ISO file identifier used for the installer CD-ROM."
  value       = local.iso_file_id
}

locals {
  iso_file_id = var.reuse_existing_iso_download ? var.existing_iso_file_id : proxmox_download_file.nixos_minimal_iso[0].id
}

resource "proxmox_download_file" "nixos_minimal_iso" {
  count = var.reuse_existing_iso_download ? 0 : 1

  node_name    = var.proxmox_node
  datastore_id = var.iso_datastore_id

  url       = var.nixos_iso_url
  file_name = var.nixos_iso_filename

  content_type = "iso"
  overwrite    = false
  verify       = var.nixos_download_verify_tls
}

resource "proxmox_virtual_environment_vm" "nixos" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = var.proxmox_node

  bios = "seabios"
  tags = concat(["nixos", "managed"], var.tags)

  machine       = var.machine_type
  scsi_hardware = "virtio-scsi-single"

  started = var.started
  on_boot = var.start_on_boot

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mib
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  cdrom {
    file_id = local.iso_file_id
  }

  boot_order = var.boot_installer_first ? ["ide2", "scsi0"] : ["scsi0", "ide2"]

  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "qcow2"
    iothread     = true
    discard      = "on"
  }

  lifecycle {
    precondition {
      condition     = !var.reuse_existing_iso_download || var.existing_iso_file_id != ""
      error_message = "When reuse_existing_iso_download is true, set existing_iso_file_id (for example \"local:iso/nixos-minimal.iso\")."
    }

    ignore_changes = [
      cdrom,
      boot_order,
    ]
  }
}

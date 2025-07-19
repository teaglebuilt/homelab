resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  node_name   = var.node
  description = "Managed by Terraform"

  tags = ["managed", var.os_type]

  cpu {
    cores   = var.cores
    sockets = 1
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    file_format  = "qcow2"
    size         = var.disk_size
    interface    = "scsi0"
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  cdrom {
    file_id = var.iso_file_id
  }

  boot_order = ["scsi0"]
  operating_system {
    type = var.os_type
  }

  agent {
    enabled = true
  }
}

resource "proxmox_vm_qemu" "talos_node" {
  count    = 1
  name     = "homelab-mlops-master0${count.index + 1}"
  target_node = "pve2"
  clone    = "talostemplate"

  disks {
    id             = 0
    size           = 10
    type           = "scsi"
    storage        = "local-lvm"
    storage_type   = "lvm"
  }

  network {
    id         = 0
    model      = "virtio"
    bridge     = "vmbr0"
  }

  cpu {
    sockets = 1
    cores   = 2
  }

  memory {
    dedicated = 4098
    dynamic   = 4098
    maximum   = 9068
  }
}

resource "proxmox_vm_qemu" "talos_node" {
  count    = 3
  name     = "homelab-mlops-worker0${count.index + 1}"
  target_node = "pve2"
  clone    = "talostemplate"

  disks {
    id             = 0
    size           = 10
    type           = "scsi"
    storage        = "local-lvm"
    storage_type   = "lvm"
  }

  network {
    id         = 0
    model      = "virtio"
    bridge     = "vmbr0"
  }

  cpu {
    sockets = 1
    cores   = 2
  }

  memory {
    dedicated = 4098
    dynamic   = 4098
    maximum   = 9068
  }
}
resource "proxmox_virtual_environment_vm" "this" {
  for_each          = var.nodes

  node_name         = each.value.host_node

  name              = each.key
  description       = each.value.machine_type == "controlplane" ? "control plane" : "worker"
  tags              = each.value.machine_type == "controlplane" ? ["k8s", "control-plane"] : ["k8s", "worker"]
  vm_id             = each.value.vm_id

  on_boot           = true
  started           = true

  machine           = "q35"
  scsi_hardware     = "virtio-scsi-single"
  bios              = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated   = each.value.ram_dedicated
    floating    = each.value.ram_dedicated / 2
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    size         = each.value.disk_size
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    file_id      = proxmox_virtual_environment_download_file.this[each.key].id
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.cluster.gateway
      }
    }
  }

  dynamic "hostpci" {
    for_each = each.value.igpu ? [1] : []
    content {
      device        = "hostpci0"
      mapping       = "nvidia_4070_super"
      pcie          = true
      rombar        = true
    }
  }

  lifecycle {
    ignore_changes = [
      tags,
      description
    ]
  }
}

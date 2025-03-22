resource "proxmox_virtual_environment_vm" "this" {
  node_name         = var.proxmox_host_node

  name              = var.node_name
  description       = var.machine_type == "controlplane" ? "control plane" : "worker"
  tags              = var.machine_type == "controlplane" ? ["k8s", "control-plane"] : ["k8s", "worker"]
  vm_id             = var.vm_id

  on_boot           = true
  started           = true

  machine           = "q35"
  scsi_hardware     = "virtio-scsi-single"
  bios              = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu
    type  = "host"
  }

  memory {
    dedicated   = var.ram_dedicated
    floating    = var.ram_dedicated / 2
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
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = var.cluster.gateway
      }
    }
  }

  dynamic "hostpci" {
    for_each = var.igpu == true ? [1] : []
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

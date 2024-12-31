resource "proxmox_virtual_environment_vm" "talos_master_node" {
  count             = 1
  name              = "mlops-master0${count.index + 1}"
  node_name         = "pve2"
  started           = false
  stop_on_destroy   = true
  on_boot           = false
  timeout_clone     = 30

  clone {
    vm_id = 202
    node_name = "pve2"
  }

  agent {
    enabled = true
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cpu {
    cores   = 2
    sockets = 1
  }

  # lifecycle {
  #   ignore_changes = [node_name, started, initialization]
  # }
}

resource "proxmox_virtual_environment_vm" "talos_worker_node" {
  count             = 2
  name              = "mlops-worker0${count.index + 1}"
  node_name         = "pve2"
  on_boot           = false
  started           = false
  stop_on_destroy   = true

  clone {
    vm_id = 202
    node_name = "pve2"
  }

  agent {
    enabled = true
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cpu {
    cores   = 2
    sockets = 1
  }

  # lifecycle {
  #   ignore_changes = [node_name, started, initialization]
  # }
}

output "master_node_info" {
  value = [for vm in proxmox_virtual_environment_vm.talos_master_node : {
    id   = vm.id
    name = vm.name
    ip   = vm.network_device
  }]
}

output "worker_node_info" {
  value = [for vm in proxmox_virtual_environment_vm.talos_worker_node : {
    id   = vm.id
    name = vm.name
    ip   = vm.network_device
  }]
}
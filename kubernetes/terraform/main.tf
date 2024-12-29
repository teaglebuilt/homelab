resource "proxmox_virtual_environment_vm" "talos_master_node" {
  count             = 1
  name              = "mlops-master0${count.index + 1}"
  node_name         = "mlops-master0${count.index + 1}"
  on_boot = true

  clone {
    vm_id = 202
    node_name = "pve2"
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id    = "local-lvm"
    size            = 10
    interface       = "scsi"
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cpu {
    cores   = 2
    sockets = 1
  }

  memory {
    dedicated = 4098
  }

  lifecycle {
    ignore_changes = [started]
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker_node" {
  count             = 2
  name              = "mlops-worker0${count.index + 1}"
  node_name         = "mlops-worker0${count.index + 1}"
  on_boot = true

  clone {
    vm_id = 202
    node_name = "pve2"
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id    = "local-lvm"
    size            = 10
    interface       = "scsi"
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cpu {
    cores   = 2
    sockets = 1
  }

  memory {
    dedicated = 6098
  }

  lifecycle {
    ignore_changes = [started]
  }
}

resource "null_resource" "wait_for_provisioning_of_worker_nodes" {
  provisioner "local-exec" {
    command = "sleep 60" # Wait for 60 seconds
  }

  triggers = {
    vm_creation = join(",", flatten([for vm in proxmox_virtual_environment_vm.talos_worker_node : vm.id]))
  }
}

output "master_node_info" {
  value = [for vm in proxmox_virtual_environment_vm.talos_master_node : {
    id   = vm.id
    name = vm.name
    ip   = vm.network_device[0].ip_address
  }]
}

output "mlops_master_node" {
  value       = [for vm in proxmox_virtual_environment_vm.talos_master_node : vm.name]
  depends_on  = [null_resource.wait_for_provisioning]
}

output "mlops_worker_nodes" {
  value       = [for vm in proxmox_virtual_environment_vm.talos_worker_node : vm.name]
  depends_on  = [null_resource.wait_for_provisioning]
}
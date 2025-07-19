provider "proxmox" {
  endpoint = var.endpoint
  user     = var.user
  password = var.password
  insecure = true
}

resource "proxmox_vm_qemu" "vm" {
  name        = var.name
  vmid        = var.vmid
  target_node = var.node

  cores   = var.cores
  memory  = var.memory
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"
  bootdisk = "scsi0"

  iso     = var.iso
  storage = var.storage
  disk    = [{ size = var.disk_size }]

  network {
    model  = "virtio"
    bridge = var.bridge
  }

  os_type = var.os_type

  connection {
    type        = var.connection_type
    user        = var.admin_user
    password    = var.admin_password
    host        = self.default_ipv4_address
  }

  provisioner "local-exec" {
    when    = create
    command = "ansible-playbook -i ${self.default_ipv4_address}, playbooks/apply-postinstall.yml --extra-vars=@${path.module}/vars.json"
  }
}

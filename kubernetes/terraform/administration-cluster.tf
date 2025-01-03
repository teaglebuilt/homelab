
resource "proxmox_vm_qemu" "k8s_cp_01" {
  name        = "k8s_cp_01"
  target_node = "k8s-cp-01"
  clone       = "100"

  disks {
    size = "32G"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0 = "ip=${var.proxmox_node_cidr},gw=${var.gateway}"
  sshkeys   = file("${var.ssh_public_key_path}")
}

resource "proxmox_vm_qemu" "k8s_worker_01" {
  name        = "k8s_worker_01"
  target_node = "k8s-worker-01"
  clone       = "100"

  disks {
    size = "32G"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0 = "ip=${var.proxmox_node_cidr},gw=${var.gateway}"
  sshkeys   = file("${var.ssh_public_key_path}")
}

module "k8s_administration_cluster" {
  source = "github.com/teaglebuilt/homelab//tf_modules/k8s_cluster?ref=master"
  depends_on = [proxmox_vm_qemu.k8s_cp_01, proxmox_vm_qemu.k8s_worker_01]

  cluster_name = var.cluster_name
  control_plane_ips = var.control_plane_ips
  worker_ips = var.worker_ips
}
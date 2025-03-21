

module "talos_node" {
  # source = "git::https://github.com/teaglebuilt/homelab.git//tf_modules/talos_cluster?ref=main"
  source = "../../tf_modules/talos_node"

  node_name                       = "mlops-ctrl-00"
  machine_type                    = "controlplane"
  proxmox_host_node               = "pve1"
  ip                              = var.master_node_ip
  vm_id                           = 100
  cpu                             = 4
  disk_size                       = 20
  ram_dedicated                   = 8096
  igpu                            = false
  proxmox_ssh_private_key         = var.proxmox_ssh_private_key

  image = {
    version = "v1.9.1"
    update_version = "v1.9.1"
  }

  cluster = {
    name            = "mlops"
    endpoint        = var.k8s_api_server_ip
    gateway         = var.network_gateway
    talos_version   = "v1.9.1"
  }
}

module "talos_node" {
  # source = "git::https://github.com/teaglebuilt/homelab.git//tf_modules/talos_cluster?ref=main"
  source = "../../tf_modules/talos_node"

  node_name                       = "mlops-work-00"
  machine_type                    = "worker"
  proxmox_host_node               = "pve2"
  ip                              = var.worker_one_node_ip
  vm_id                           = 102
  cpu                             = 8
  disk_size                       = 30
  ram_dedicated                   = 24336
  igpu                            = true
  pci = {
    id = "10de:2783"
    name = "nvidia_4070_super"
    iommu_group = 23
    node = "pve2"
    path = "0000:2e:00.0"
    subsystem_id = "10de:18fe"
  }
  proxmox_ssh_private_key         = var.proxmox_ssh_private_key

  image = {
    version = "v1.9.1"
    update_version = "v1.9.1"
  }

  cluster = {
    name            = "mlops"
    endpoint        = var.k8s_api_server_ip
    gateway         = var.network_gateway
    talos_version   = "v1.9.1"
  }
}

module "talos_node" {
  # source = "git::https://github.com/teaglebuilt/homelab.git//tf_modules/talos_cluster?ref=main"
  source = "../../tf_modules/talos_node"

  node_name                       = "mlops-work-01"
  machine_type                    = "worker"
  proxmox_host_node               = "pve1"
  ip                              = var.worker_two_node_ip
  vm_id                           = 103
  cpu                             = 8
  disk_size                       = 20
  ram_dedicated                   = 10120
  igpu                            = false
  proxmox_ssh_private_key         = var.proxmox_ssh_private_key

  image = {
    version = "v1.9.1"
    update_version = "v1.9.1"
  }

  cluster = {
    name            = "mlops"
    endpoint        = var.k8s_api_server_ip
    gateway         = var.network_gateway
    talos_version   = "v1.9.1"
  }
}

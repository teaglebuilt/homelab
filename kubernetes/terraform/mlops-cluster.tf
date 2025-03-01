module "talos_cluster" {
  # source = "git::https://github.com/teaglebuilt/homelab.git//tf_modules/talos_cluster?ref=gateway-api"
  source = "../../tf_modules/talos_cluster"

  proxmox_ssh_private_key = var.proxmox_ssh_private_key

  image = {
    version = "v1.9.1"
    update_version = "v1.9.1" # renovate: github-releases=siderolabs/talos
  }

  cluster = {
    name            = "mlops"
    endpoint        = var.k8s_api_server_ip
    gateway         = var.network_gateway
    talos_version   = "v1.9.1"
    proxmox_cluster = "mlops"
  }

  nodes = {
    "mlops-ctrl-00" = {
      host_node     = "pve2"
      machine_type  = "controlplane"
      ip            = var.master_node_ip
      vm_id         = 100
      cpu           = 8
      disk_size     = 20
      ram_dedicated = 10480
    }
    "mlops-work-00" = {
      host_node     = "pve2"
      machine_type  = "worker"
      ip            = var.worker_one_node_ip
      vm_id         = 102
      cpu           = 8
      disk_size     = 30
      ram_dedicated = 20480
      igpu          = true
      pci           = {
        id = "10de:2783"
        name = "nvidia_4070_super"
        iommu_group = 20
        node = "pve2"
        path = "0000:2e:00.0"
        subsystem_id = "10de:18fe"
      }
    }
    "mlops-work-01" = {
      host_node     = "pve2"
      machine_type  = "worker"
      ip            = var.worker_two_node_ip
      vm_id         = 103
      cpu           = 8
      disk_size     = 20
      ram_dedicated = 20480
    }
  }
}


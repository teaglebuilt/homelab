module "talos_cluster" {
  source = "../../../tf_modules/talos_cluster"

  proxmox_ssh_private_key = var.proxmox_ssh_private_key

  image = {
    version        = "v1.11.5"
    update_version = "v1.11.5" # renovate: github-releases=siderolabs/talos
  }

  cluster = {
    name               = "application"
    endpoint           = var.admin_k8s_api_server_ip
    gateway            = var.network_gateway
    talos_version      = "v1.11.5"
    kubernetes_version = "1.32.2"
    cluster_name       = "application"
    logging_server     = var.graylog_ip
    pod_subnet         = "10.245.0.0/16"
    service_subnet     = "10.97.0.0/16"
  }

  nodes = {
    "application-ctrl-00" = {
      host_node     = "pve"
      machine_type  = "controlplane"
      ip            = var.admin_master_node_ip
      vm_id         = 500
      cpu           = 4
      disk_size     = 20
      ram_dedicated = 8192
    }
    "application-work-00" = {
      host_node     = "pve"
      machine_type  = "worker"
      ip            = var.admin_worker_node_ip
      vm_id         = 501
      cpu           = 4
      disk_size     = 40
      ram_dedicated = 8192
    }
  }
}

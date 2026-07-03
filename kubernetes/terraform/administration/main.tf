module "talos_cluster" {
  source = "../../../tf_modules/talos_cluster"

  proxmox_ssh_private_key = var.proxmox_ssh_private_key

  image = {
    version        = "v1.11.5"
    update_version = "v1.11.5" # renovate: github-releases=siderolabs/talos
  }

  cluster = {
    name               = "administration"
    endpoint           = var.admin_k8s_api_server_ip
    gateway            = var.network_gateway
    talos_version      = "v1.11.5"
    kubernetes_version = "1.32.2"
    proxmox_cluster    = "administration"
    logging_server     = var.graylog_ip
    # Disjoint from mlops (10.244.0.0/16) — hard requirement for ClusterMesh.
    pod_subnet         = "10.245.0.0/16"
    service_subnet     = "10.97.0.0/16"
  }

  # Minimal control-plane + worker on the standalone pve1 host. VM IDs are local
  # to pve1 so they don't collide with mlops (which lives on pve2). Adjust sizing
  # to the admin workload once real hardware headroom is known.
  nodes = {
    "administration-ctrl-00" = {
      host_node     = "pve1"
      machine_type  = "controlplane"
      ip            = var.admin_master_node_ip
      vm_id         = 100
      cpu           = 4
      disk_size     = 20
      ram_dedicated = 4096
    }
    "administration-work-00" = {
      host_node     = "pve1"
      machine_type  = "worker"
      ip            = var.admin_worker_node_ip
      vm_id         = 101
      cpu           = 4
      disk_size     = 40
      ram_dedicated = 8192
    }
  }
}

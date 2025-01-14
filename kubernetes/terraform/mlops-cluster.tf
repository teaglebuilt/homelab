module "talos_cluster" {
  source = "https://github.com/teaglebuilt/homelab.git//tf_modules/talos_cluster?ref=terraform_talos"

  providers = {
    proxmox = proxmox
  }

  image = {
    version = "v1.9.1"
    update_version = "v1.9.1" # renovate: github-releases=siderolabs/talos
    schematic = file("${path.module}/../clusters/mlops/patches/schemantics.yaml")
  }

  cluster = {
    name            = "mlops"
    endpoint        = var.k8s_api_server
    gateway         = var.network_gateway
    talos_version   = "v1.9"
    proxmox_cluster = "homelab"
  }

  nodes = {
    "mlops-ctrl-00" = {
      host_node     = "pve2"
      machine_type  = "controlplane"
      ip            = var.master_node_ip
      vm_id         = 800
      cpu           = 8
      ram_dedicated = 20480
      igpu          = false
    }
    "mlops-work-00" = {
      host_node     = "pve2"
      machine_type  = "worker"
      ip            = var.worker_node_ip
      vm_id         = 810
      cpu           = 8
      ram_dedicated = 4096
      igpu          = false
    }
  }

  cilium = {
    values = file("${path.module}/../apps/kube-system/cilium/values.yaml")
    install = file("${path.module}/manifests/cilium.yaml")
  }
}
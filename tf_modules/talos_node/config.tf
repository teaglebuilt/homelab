resource "talos_machine_secrets" "machine_secrets" {
  talos_version = var.cluster.talos_version
}

data "talos_client_configuration" "machine_client_configuration" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = var.machine_type == "controlplane" ? [var.ip] : []
}

data "talos_machine_configuration" "machine_config" {
  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${var.cluster.endpoint}:6443"
  talos_version    = var.cluster.talos_version
  machine_type     = var.machine_type
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  config_patches = var.machine_type == "controlplane" ? [
    templatefile("${path.module}/templates/controlplane.yaml.tftpl", {
      hostname        = var.node_name
      node_name       = var.proxmox_host_node
      node_ip         = var.ip
      cluster_name    = var.cluster.name
      network_gateway = var.cluster.gateway
    }),
    file("${path.module}/patches/controlplane/api-server-access.yaml"),
    file("${path.module}/patches/local-path-storage.yaml"),
    file("${path.module}/patches/containerd.yaml"),
    file("${path.module}/patches/kubelet.yaml")
  ] : concat([
    templatefile("${path.module}/templates/worker.yaml.tftpl", {
      hostname        = var.node_name
      node_name       = var.proxmox_host_node
      node_ip         = var.ip
      cluster_name    = var.cluster.name
      network_gateway = var.cluster.gateway
    }),
    file("${path.module}/patches/local-path-storage.yaml"),
    file("${path.module}/patches/containerd.yaml"),
    file("${path.module}/patches/kubelet.yaml")
  ], var.igpu ? [
    file("${path.module}/patches/worker/gpu-worker-patch.yaml"),
    file("${path.module}/patches/worker/gpu-worker-label.yaml"),
  ] : [])
}

resource "talos_machine_configuration_apply" "this" {
  depends_on = [proxmox_virtual_environment_vm.this]
  node                        = var.ip
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machine_config.machine_configuration
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.this]
  }
}

resource "talos_machine_bootstrap" "bootstrap_etcd" {
  depends_on = [talos_machine_configuration_apply.this]
  node                 = var.ip
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [talos_machine_bootstrap.bootstrap_etcd]
  node                 = var.ip
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  timeouts = {
    read = "1m"
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each            = var.nodes
  cluster_name        = var.cluster.name
  cluster_endpoint    = "https://${var.cluster.endpoint}:6443"
  talos_version       = var.cluster.talos_version
  kubernetes_version  = var.cluster.kubernetes_version
  machine_type        = each.value.machine_type
  machine_secrets     = talos_machine_secrets.this.machine_secrets
  config_patches = each.value.machine_type == "controlplane" ? [
    templatefile("${path.module}/templates/controlplane.yaml.tftpl", {
      hostname        = each.key
      node_name       = each.value.host_node
      node_ip         = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
      cluster_name    = var.cluster.proxmox_cluster
      network_gateway = var.cluster.gateway
    }),
    file("${path.module}/patches/controlplane/api-server-access.yaml"),
    file("${path.module}/patches/local-path-storage.yaml"),
    file("${path.module}/patches/containerd.yaml"),
    file("${path.module}/patches/kubelet.yaml")
  ] : concat([
    templatefile("${path.module}/templates/worker.yaml.tftpl", {
      hostname        = each.key
      node_name       = each.value.host_node
      node_ip         = each.value.ip
      cluster_name    = var.cluster.proxmox_cluster
      network_gateway = var.cluster.gateway
    }),
    file("${path.module}/patches/local-path-storage.yaml"),
    file("${path.module}/patches/containerd.yaml"),
    file("${path.module}/patches/kubelet.yaml"),
    file("${path.module}/patches/worker/wasm-worker-label.yaml")
  ], each.value.igpu ? [
    file("${path.module}/patches/worker/gpu-worker-patch.yaml"),
    file("${path.module}/patches/worker/gpu-worker-label.yaml"),
  ] : [])
}

resource "talos_machine_configuration_apply" "this" {
  depends_on = [proxmox_virtual_environment_vm.this]
  for_each                    = var.nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  lifecycle {
    # re-run config apply if vm changes
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
  timeouts = {
    read = "1m"
  }
}

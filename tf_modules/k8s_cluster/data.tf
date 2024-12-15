resource "talos_machine_secrets" "machine_secrets" {}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = var.control_plane_ips
}

data "talos_machine_configuration" "control_plane" {
  for_each            = toset(var.control_plane_ips)
  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${each.value}:6443"
  machine_type         = "controlplane"
  machine_secrets      = talos_machine_secrets.machine_secrets.machine_secrets
}

data "talos_machine_configuration" "worker" {
  for_each            = toset(var.worker_ips)
  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${each.value}:6443"
  machine_type         = "controlplane"
  machine_secrets      = talos_machine_secrets.machine_secrets.machine_secrets
}

data "talos_cluster_health" "health" {
  depends_on           = [ talos_machine_configuration_apply.control_plane_config_apply, talos_machine_configuration_apply.worker_config_apply ]
  client_configuration = data.talos_client_configuration.talosconfig.client_configuration
  control_plane_nodes  = var.control_plane_ips
  worker_nodes         = var.worker_ips
  endpoints            = data.talos_client_configuration.talosconfig.endpoints
}

data "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [ talos_machine_bootstrap.bootstrap, data.talos_cluster_health.health ]
  node         = var.node_ip
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
}

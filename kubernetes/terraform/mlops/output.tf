

resource "local_file" "talos_config" {
  content         = module.talos_cluster.talosconfig.talos_config
  filename        = "../../generated/mlops/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  # Talos names the context and user admin@<cluster>. Use the cluster name.
  content         = replace(module.talos_cluster.kubeconfig.kubeconfig_raw, "admin@mlops", "mlops")
  filename        = "../../generated/mlops/kubeconfig"
  file_permission = "0600"
}

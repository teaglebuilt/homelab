resource "local_file" "talos_config" {
  content         = module.talos_cluster.talosconfig.talos_config
  filename        = "../../generated/application/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  content         = module.talos_cluster.kubeconfig.kubeconfig_raw
  filename        = "../../generated/application/kubeconfig"
  file_permission = "0600"
}

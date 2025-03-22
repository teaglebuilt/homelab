

resource "local_file" "talos_config" {
  content         = module.mlops-ctrl-00.talosconfig.talos_config
  filename        = "../generated/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  content         = module.mlops-ctrl-00.kubeconfig.kubeconfig_raw
  filename        = "../generated/kubeconfig"
  file_permission = "0600"
}

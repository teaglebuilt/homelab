# Write administration's talosconfig/kubeconfig to a dedicated dir so they never
# collide with mlops (kubernetes/generated/{talosconfig,kubeconfig}).
resource "local_file" "talos_config" {
  content         = module.talos_cluster.talosconfig.talos_config
  filename        = "../../generated/administration/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  content         = module.talos_cluster.kubeconfig.kubeconfig_raw
  filename        = "../../generated/administration/kubeconfig"
  file_permission = "0600"
}

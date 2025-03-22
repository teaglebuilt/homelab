output "machine_config" {
  value = data.talos_machine_configuration.machine_config
}

output "talosconfig" {
  value     = data.talos_client_configuration.machine_client_configuration
  sensitive = true
}

output "kubeconfig" {
  value =  talos_cluster_kubeconfig.kubeconfig
  sensitive = true
}

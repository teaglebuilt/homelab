output "machine_config" {
  value = data.talos_machine_configuration.this
}

output "talosconfig" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "kubeconfig" {
  value =  talos_cluster_kubeconfig.this
  sensitive = true
}

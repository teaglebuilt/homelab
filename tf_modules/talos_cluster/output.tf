output "machine_config" {
  value = data.talos_machine_configuration.this
}

output "installer_images" {
  description = "Per-node factory installer refs, for `talosctl upgrade --image`."
  value       = { for k, v in data.talos_image_factory_urls.this : k => v.urls.installer }
}

output "talosconfig" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "kubeconfig" {
  value =  talos_cluster_kubeconfig.this
  sensitive = true
}

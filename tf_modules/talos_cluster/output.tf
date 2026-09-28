output "machine_config" {
  value = data.talos_machine_configuration.this
}

output "required_images" {
  description = "Talos images each node boots from, keyed by image key. Consumed by the talos:seed-images task."
  value = {
    for key, image in local.images : key => {
      host_node = image.host_node
      datastore = var.image.proxmox_datastore
      file_name = local.image_file_name[key]
      file_id   = local.image_file_id[key]
      url       = "${var.image.factory_url}/image/${talos_image_factory_schematic.this[image.node].id}/${var.image.version}/${local.image_asset}.raw.gz"
    }
  }
}

output "talosconfig" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "kubeconfig" {
  value =  talos_cluster_kubeconfig.this
  sensitive = true
}

resource "proxmox_virtual_environment_download_file" "talos_controlplane_image_download" {
  for_each = toset( formatlist("%s-controlplane", local.proxmox_nodes))

  provider     = proxmox
  node_name    = split("-", each.key)[0]
  content_type = "iso"
  datastore_id = "local"
  file_name    = "talos-controlplane-v${var.talos_data.talos_version}-amd64.iso"

  url = "https://factory.talos.dev/image/${local.talos_controlplane_schematic_id}/v${var.talos_data.talos_version}/metal-amd64.iso"
}

resource "proxmox_virtual_environment_download_file" "talos_worker_image_download" {
  for_each = toset( formatlist("%s-worker", local.proxmox_nodes))

  provider     = proxmox
  node_name    = split("-", each.key)[0]
  content_type = "iso"
  datastore_id = "local"
  file_name    = "talos-worker-v${var.talos_data.talos_version}-amd64.iso"

  url = "https://factory.talos.dev/image/${local.talos_worker_schematic_id}/v${var.talos_data.talos_version}/metal-amd64.iso"
}

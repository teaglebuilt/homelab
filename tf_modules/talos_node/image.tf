resource "talos_image_factory_schematic" "this" {
  for_each = var.nodes

  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = distinct(concat(
          ["siderolabs/qemu-guest-agent"],
          each.value.machine_type == "worker" && lookup(each.value, "igpu", false) ? [
            "siderolabs/nvidia-container-toolkit-production",
            "siderolabs/nonfree-kmod-nvidia-production"
          ] : []
        ))
      }
    }
  })
}

resource "proxmox_virtual_environment_download_file" "this" {
  for_each = {
    for k, v in var.nodes : k => v
    if !fileexists("/var/lib/vz/template/iso/talos-${k}-nocloud-amd64.img")
  }

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = "local"

  file_name               = "talos-${each.key}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.this[each.key].id}/${var.image.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  verify                  = true
  overwrite               = false
}

resource "talos_image_factory_schematic" "talos_image" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = distinct(concat(
          ["siderolabs/qemu-guest-agent"],
          var.machine_type == "worker" && lookup(each.value, "igpu", false) ? [
            "siderolabs/nvidia-container-toolkit-production",
            "siderolabs/nonfree-kmod-nvidia-production"
          ] : []
        ))
      }
    }
  })
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  node_name    = var.node_name
  content_type = "iso"
  datastore_id = "local"

  file_name               = "talos-${var.node_name}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.talos_image}/${var.image.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  verify                  = true
  overwrite               = false
}

resource "talos_image_factory_schematic" "this" {
  for_each = var.nodes

  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = distinct(concat(
          ["siderolabs/qemu-guest-agent"],
          each.value.machine_type == "worker" && lookup(each.value, "igpu", false) ? [
            "siderolabs/nvidia-container-toolkit-production",
            "siderolabs/nvidia-open-gpu-kernel-modules-production"
          ] : []
        ))
      }
    }
  })
}

resource "proxmox_download_file" "this" {
  for_each = var.nodes

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = "local"

  file_name               = "talos-${each.key}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.this[each.key].id}/${var.image.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  verify                  = var.cluster.verify_image_download
  overwrite               = false

  lifecycle {
    ignore_changes = [url, verify, overwrite, decompression_algorithm]
  }
}

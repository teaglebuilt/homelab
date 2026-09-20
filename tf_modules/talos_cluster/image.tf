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

data "talos_image_factory_urls" "this" {
  for_each = var.nodes

  talos_version = var.image.version
  schematic_id  = talos_image_factory_schematic.this[each.key].id
  architecture  = var.image.arch
  platform      = var.image.platform
}

resource "proxmox_virtual_environment_download_file" "this" {
  for_each = {
    for k, v in var.nodes : k => v
    if !fileexists("/var/lib/vz/template/iso/talos-${k}-nocloud-amd64.img")
  }

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = "local"

  file_name = "talos-${each.key}-nocloud-amd64.img"
  # Not data.talos_image_factory_urls.this[*].urls.disk_image: that yields
  # .raw.xz, and decompression_algorithm only accepts gz/lzo/zst/bz2.
  url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.this[each.key].id}/${var.image.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  verify                  = var.cluster.verify_image_download
  overwrite               = false
  # PVE defaults to 600s. The igpu schematic bundles the NVIDIA kernel modules
  # and container toolkit, so that image is ~750MB against ~195MB for the base
  # one and does not finish inside 10min on this uplink.
  upload_timeout = var.image.upload_timeout
}

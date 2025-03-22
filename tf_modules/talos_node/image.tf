locals {
  talos_image_id = var.igpu ? talos_image_factory_schematic.talos_gpu_image.id : talos_image_factory_schematic.talos_image.id
}

resource "talos_image_factory_schematic" "talos_image" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = ["siderolabs/qemu-guest-agent"]
      }
    }
  })
}

resource "talos_image_factory_schematic" "talos_gpu_image" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
          "siderolabs/nvidia-container-toolkit-production",
          "siderolabs/nonfree-kmod-nvidia-production"
        ],
      }
    }
  })
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  node_name    = var.proxmox_host_node
  content_type = "iso"
  datastore_id = "local"

  file_name               = "talos-${var.node_name}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/${local.talos_image_id}/${var.image.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  verify                  = true
  overwrite               = false
}

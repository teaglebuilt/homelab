locals {
  gpu_node = {
    for k, v in var.nodes : k => v.machine_type == "worker" && lookup(v, "igpu", false)
  }

  # see docs/adr/0001-gpu-node-stability-on-mlops.md (Decision 5)
  gpu_kernel_args = ["pcie_aspm=off"]

  node_schematic = {
    for k, v in var.nodes : k => yamlencode({
      customization = merge(
        local.gpu_node[k] ? { extraKernelArgs = local.gpu_kernel_args } : {},
        {
          systemExtensions = {
            officialExtensions = distinct(concat(
              ["siderolabs/qemu-guest-agent"],
              local.gpu_node[k] ? [
                "siderolabs/nvidia-container-toolkit-production",
                "siderolabs/nvidia-open-gpu-kernel-modules-production"
              ] : []
            ))
          }
        }
      )
    })
  }

  node_image_hash = {
    for k, v in var.nodes : k => substr(sha256(local.node_schematic[k]), 0, 12)
  }

  node_image_key = {
    for k, v in var.nodes : k => "${v.host_node}-${local.node_image_hash[k]}"
  }

  image_nodes = {
    for k, v in var.nodes : local.node_image_key[k] => k...
  }

  images = {
    for key, nodes in local.image_nodes : key => {
      node      = nodes[0]
      host_node = var.nodes[nodes[0]].host_node
      hash      = local.node_image_hash[nodes[0]]
    }
  }

  image_asset = "${var.image.platform}-${var.image.arch}"

  image_file_name = {
    for key, image in local.images :
    key => "talos-${var.image.version}-${image.hash}-${local.image_asset}.img"
  }

  image_file_id = {
    for key, image in local.images :
    key => "${var.image.proxmox_datastore}:iso/${local.image_file_name[key]}"
  }
}

resource "talos_image_factory_schematic" "this" {
  for_each = var.nodes

  schematic = local.node_schematic[each.key]
}

resource "proxmox_download_file" "this" {
  for_each = local.images

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = var.image.proxmox_datastore

  file_name               = local.image_file_name[each.key]
  url                     = "${var.image.factory_url}/image/${talos_image_factory_schematic.this[each.value.node].id}/${var.image.version}/${local.image_asset}.raw.gz"
  decompression_algorithm = "gz"
  verify                  = var.cluster.verify_image_download
  overwrite               = false
  upload_timeout          = var.image.download_timeout

  lifecycle {
    ignore_changes = [verify, overwrite, decompression_algorithm]
  }
}

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
}

resource "talos_image_factory_schematic" "this" {
  for_each = var.nodes

  schematic = local.node_schematic[each.key]
}

resource "proxmox_download_file" "this" {
  for_each = local.images

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = "local"

  file_name               = "talos-${var.image.version}-${each.value.hash}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.this[each.value.node].id}/${var.image.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  verify                  = var.cluster.verify_image_download
  overwrite               = false
  upload_timeout          = var.image.download_timeout

  lifecycle {
    ignore_changes = [verify, overwrite, decompression_algorithm]
  }
}

resource "proxmox_virtual_environment_file" "nix_os_iso" {
  for_each     = toset(data.proxmox_virtual_environment_nodes.available_nodes.names)
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.key

  source_file {
    path      = "https://mirror.nju.edu.cn/nixos-images/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso" # China NixOS Mirror https://mirrors.cernet.edu.cn/os/NixOS
    file_name = "nixos-minimal-24.05.iso"
  }
}
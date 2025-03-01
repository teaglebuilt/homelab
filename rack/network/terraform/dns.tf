resource "unifi_dns_host_record" "proxmox_node_one" {
  name    = "proxmox_node_one"
  address = var.proxmox_node_one
  type    = "A"
}

resource "unifi_dns_host_record" "proxmox_node_two" {
  name    = "proxmox_node_two"
  address = var.proxmox_node_two
  type    = "A"
}
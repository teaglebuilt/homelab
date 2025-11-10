
resource "unifi_dns_host_record" "proxmox_node_one" {
  name    = "proxmox-node-one"
  address = var.proxmox_node_one
  type    = "A"
}

resource "unifi_dns_host_record" "proxmox_node_two" {
  name    = "proxmox-node-two"
  address = var.proxmox_node_two
  type    = "A"
}

resource "unifi_dns_host_record" "additional" {
  for_each = var.dns_records

  name    = each.value.name
  address = each.value.address
  type    = each.value.type
}

resource "unifi_network" "networks" {
  for_each = var.networks

  name    = each.value.name
  purpose = "corporate"

  subnet        = each.value.subnet
  vlan_id       = each.value.vlan_id
  dhcp_enabled  = each.value.dhcp_enabled
  dhcp_start    = each.value.dhcp_start
  dhcp_stop     = each.value.dhcp_stop
  dhcp_dns      = each.value.dhcp_dns
  domain_name   = each.value.domain_name

  igmp_snooping       = each.value.igmp_snooping
  multicast_dns_enabled = each.value.multicast_dns

  ipv6_interface_type = each.value.ipv6_enabled ? "static" : "none"

  network_group = each.value.network_group
}

resource "unifi_firewall_rule" "rules" {
  for_each = { for idx, rule in var.firewall_rules : "${rule.ruleset}_${rule.rule_index}" => rule }

  name       = each.value.name
  action     = each.value.action
  rule_index = each.value.rule_index
  ruleset    = each.value.ruleset

  protocol    = each.value.protocol
  src_network = each.value.src_network
  src_address = each.value.src_address
  src_port    = each.value.src_port
  dst_network = each.value.dst_network
  dst_address = each.value.dst_address
  dst_port    = each.value.dst_port

  logging = each.value.logging
  enabled = each.value.enabled
}

resource "unifi_wlan" "wifi" {
  for_each = var.wifi_ssids

  name       = each.value.name
  passphrase = each.value.passphrase
  security   = each.value.security
  network_id    = each.value.network_id != null ? each.value.network_id : unifi_network.networks["default"].id
  user_group_id = each.value.user_group_id
  hide_ssid         = each.value.hide_ssid
  is_guest          = each.value.is_guest
  multicast_enhance = each.value.multicast_enhance
  bss_transition       = each.value.bss_transition
  uapsd               = each.value.uapsd
  fast_roaming_enabled = each.value.fast_roaming_enabled
  pmf_mode            = each.value.pmf_mode
  minimum_data_rate_2g_kbps = each.value.minimum_data_rate_2g
  minimum_data_rate_5g_kbps = each.value.minimum_data_rate_5g
  wlan_band = join(",", each.value.wlan_bands)
}

resource "unifi_port_forward" "forwards" {
  for_each = { for idx, fwd in var.port_forwards : fwd.name => fwd }

  name     = each.value.name
  dst_port = each.value.dst_port
  fwd_ip   = each.value.fwd_ip
  fwd_port = each.value.fwd_port
  protocol = each.value.protocol
  src_ip   = each.value.src_ip
  log      = each.value.log
  enabled  = each.value.enabled
}

resource "unifi_static_route" "routes" {
  for_each = var.static_routes

  name     = each.value.name
  network  = each.value.network
  distance = each.value.distance
  next_hop = each.value.next_hop
  type     = "nexthop-route"
}

resource "unifi_user_group" "groups" {
  for_each = var.user_groups

  name              = each.value.name
  qos_rate_max_down = each.value.qos_rate_max_down
  qos_rate_max_up   = each.value.qos_rate_max_up
}

resource "unifi_setting_mgmt" "dhcp_options" {
  for_each = { for opt in var.dhcp_options : "${opt.code}_${opt.name}" => opt }

  site = var.unifi_site
}

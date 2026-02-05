# ──────────────────────────────────────────────
# VLAN Networks
# ──────────────────────────────────────────────

resource "unifi_network" "vlans" {
  for_each = var.vlans

  name         = each.value.name
  purpose      = each.value.purpose
  vlan_id      = each.value.vlan_id
  subnet       = each.value.subnet
  dhcp_start   = each.value.dhcp_start
  dhcp_stop    = each.value.dhcp_stop
  dhcp_enabled = true
}

# ──────────────────────────────────────────────
# WiFi SSIDs
# ──────────────────────────────────────────────

resource "unifi_wlan" "home" {
  name       = "HomeNet"
  security   = "wpapsk"
  passphrase = var.wifi_trusted_password
  network_id = unifi_network.vlans["trusted"].id

  wpa3_support    = true
  wpa3_transition = true
}

resource "unifi_wlan" "iot" {
  name       = "HomeNet-IoT"
  security   = "wpapsk"
  passphrase = var.wifi_iot_password
  network_id = unifi_network.vlans["iot"].id
}

resource "unifi_wlan" "guest" {
  name       = "HomeNet-Guest"
  security   = "wpapsk"
  passphrase = var.wifi_guest_password
  network_id = unifi_network.vlans["guest"].id
  is_guest   = true
}

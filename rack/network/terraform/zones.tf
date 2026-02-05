# ──────────────────────────────────────────────
# Firewall Zones (v2 zone-based firewall)
# ──────────────────────────────────────────────

resource "unifi_firewall_zone" "trusted" {
  name        = "Trusted"
  network_ids = [unifi_network.vlans["trusted"].id]
}

resource "unifi_firewall_zone" "media" {
  name        = "Media"
  network_ids = [unifi_network.vlans["media"].id]
}

resource "unifi_firewall_zone" "downloads" {
  name        = "Downloads"
  network_ids = [unifi_network.vlans["downloads"].id]
}

resource "unifi_firewall_zone" "iot" {
  name        = "IoT"
  network_ids = [unifi_network.vlans["iot"].id]
}

resource "unifi_firewall_zone" "guest" {
  name        = "Guest"
  network_ids = [unifi_network.vlans["guest"].id]
}

resource "unifi_firewall_zone" "lab" {
  name        = "Lab"
  network_ids = [unifi_network.vlans["lab"].id]
}

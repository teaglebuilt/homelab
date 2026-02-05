# ──────────────────────────────────────────────
# Traffic Rules (QoS / bandwidth management)
# ──────────────────────────────────────────────

# Prioritize Plex streaming traffic
resource "unifi_traffic_rule" "plex_priority" {
  name            = "Plex Priority"
  action          = "ALLOW"
  enabled         = true
  matching_target = "IP"
  network_id      = unifi_network.vlans["media"].id
  ip_addresses    = [var.media_server_ip]
  description     = "Prioritize Plex streaming traffic"
}

# Throttle downloads to 80% of WAN
resource "unifi_traffic_rule" "downloads_throttle" {
  name            = "Downloads Throttle"
  action          = "ALLOW"
  enabled         = true
  matching_target = "INTERNET"
  network_id      = unifi_network.vlans["downloads"].id
  description     = "Limit download VLAN to 80% of WAN bandwidth"

  bandwidth_limit {
    download_limit_kbps = var.wan_bandwidth_kbps * 80 / 100
    upload_limit_kbps   = var.wan_bandwidth_kbps * 80 / 100
  }
}

# Cap guest bandwidth
resource "unifi_traffic_rule" "guest_cap" {
  name            = "Guest Bandwidth Cap"
  action          = "ALLOW"
  enabled         = true
  matching_target = "INTERNET"
  network_id      = unifi_network.vlans["guest"].id
  description     = "Limit guest network to 25 Mbps"

  bandwidth_limit {
    download_limit_kbps = 25000
    upload_limit_kbps   = 10000
  }
}

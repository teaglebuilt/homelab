# Trusted → Management (SSH, HTTPS, UniFi controller)
resource "unifi_firewall_policy" "trusted_to_mgmt" {
  name     = "Trusted to Management"
  action   = "ALLOW"
  index    = 1000
  protocol = "tcp"

  source {
    zone_id = unifi_firewall_zone.trusted.id
  }

  destination {
    zone_id = unifi_firewall_zone.trusted.id # gateway zone handles mgmt
    port    = "22,443,8443"
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Trusted → Media (all media service ports)
resource "unifi_firewall_policy" "trusted_to_media" {
  name     = "Trusted to Media Services"
  action   = "ALLOW"
  index    = 1001
  protocol = "tcp"

  source {
    zone_id = unifi_firewall_zone.trusted.id
  }

  destination {
    zone_id = unifi_firewall_zone.media.id
    ips     = [var.media_server_ip]
    port    = "32400,5055,8989,7878,9696"
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Trusted → Downloads (qBittorrent WebUI only)
resource "unifi_firewall_policy" "trusted_to_downloads" {
  name     = "Trusted to qBit WebUI"
  action   = "ALLOW"
  index    = 1002
  protocol = "tcp"

  source {
    zone_id = unifi_firewall_zone.trusted.id
  }

  destination {
    zone_id = unifi_firewall_zone.downloads.id
    ips     = [var.downloads_server_ip]
    port    = "8080"
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Trusted → Lab (full access)
resource "unifi_firewall_policy" "trusted_to_lab" {
  name     = "Trusted to Lab Full"
  action   = "ALLOW"
  index    = 1003
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.trusted.id
  }

  destination {
    zone_id = unifi_firewall_zone.lab.id
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Trusted → IoT (full access for management)
resource "unifi_firewall_policy" "trusted_to_iot" {
  name     = "Trusted to IoT"
  action   = "ALLOW"
  index    = 1004
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.trusted.id
  }

  destination {
    zone_id = unifi_firewall_zone.iot.id
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Media → Downloads (Sonarr/Radarr talk to qBittorrent)
resource "unifi_firewall_policy" "media_to_downloads" {
  name     = "Media to Downloads qBit"
  action   = "ALLOW"
  index    = 1005
  protocol = "tcp"

  source {
    zone_id = unifi_firewall_zone.media.id
  }

  destination {
    zone_id = unifi_firewall_zone.downloads.id
    ips     = [var.downloads_server_ip]
    port    = "8080"
  }

  schedule {
    mode = "ALWAYS"
  }
}

# IoT → Media (Plex + Overseerr for smart TVs)
resource "unifi_firewall_policy" "iot_to_plex" {
  name     = "IoT to Plex and Overseerr"
  action   = "ALLOW"
  index    = 1006
  protocol = "tcp"

  source {
    zone_id = unifi_firewall_zone.iot.id
  }

  destination {
    zone_id = unifi_firewall_zone.media.id
    ips     = [var.media_server_ip]
    port    = "32400,5055"
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Lab → Media (Plex streaming from lab pods)
resource "unifi_firewall_policy" "lab_to_plex" {
  name     = "Lab to Plex"
  action   = "ALLOW"
  index    = 1007
  protocol = "tcp"

  source {
    zone_id = unifi_firewall_zone.lab.id
  }

  destination {
    zone_id = unifi_firewall_zone.media.id
    ips     = [var.media_server_ip]
    port    = "32400,5055"
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Downloads → any internal zone (fully isolated)
resource "unifi_firewall_policy" "block_downloads" {
  name     = "Block Downloads to LAN"
  action   = "BLOCK"
  index    = 2000
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.downloads.id
  }

  destination {
    ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  schedule {
    mode = "ALWAYS"
  }
}

# IoT → any internal zone
resource "unifi_firewall_policy" "block_iot" {
  name     = "Block IoT to LAN"
  action   = "BLOCK"
  index    = 2001
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.iot.id
  }

  destination {
    ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Guest → any internal zone
resource "unifi_firewall_policy" "block_guest" {
  name     = "Block Guest to LAN"
  action   = "BLOCK"
  index    = 2002
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.guest.id
  }

  destination {
    ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Media → any internal zone
resource "unifi_firewall_policy" "block_media" {
  name     = "Block Media to LAN"
  action   = "BLOCK"
  index    = 2003
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.media.id
  }

  destination {
    ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  schedule {
    mode = "ALWAYS"
  }
}

# Lab → any internal zone
resource "unifi_firewall_policy" "block_lab" {
  name     = "Block Lab to LAN"
  action   = "BLOCK"
  index    = 2004
  protocol = "all"

  source {
    zone_id = unifi_firewall_zone.lab.id
  }

  destination {
    ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  schedule {
    mode = "ALWAYS"
  }
}

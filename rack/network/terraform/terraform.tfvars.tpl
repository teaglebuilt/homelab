unifi_base_url = "${UNIFI_BASE_URL}"
unifi_api_key  = "${UNIFI_API_KEY}"

media_server_ip     = "${MEDIA_SERVER_IP}"
downloads_server_ip = "${DOWNLOADS_SERVER_IP}"

vlans = {
  trusted = {
    name       = "Trusted"
    vlan_id    = 20
    subnet     = "${VLAN_TRUSTED_SUBNET}"
    dhcp_start = "${VLAN_TRUSTED_DHCP_START}"
    dhcp_stop  = "${VLAN_TRUSTED_DHCP_STOP}"
    purpose    = "corporate"
  }
  media = {
    name       = "Media"
    vlan_id    = 30
    subnet     = "${VLAN_MEDIA_SUBNET}"
    dhcp_start = "${VLAN_MEDIA_DHCP_START}"
    dhcp_stop  = "${VLAN_MEDIA_DHCP_STOP}"
    purpose    = "corporate"
  }
  downloads = {
    name       = "Downloads"
    vlan_id    = 40
    subnet     = "${VLAN_DOWNLOADS_SUBNET}"
    dhcp_start = "${VLAN_DOWNLOADS_DHCP_START}"
    dhcp_stop  = "${VLAN_DOWNLOADS_DHCP_STOP}"
    purpose    = "corporate"
  }
  iot = {
    name       = "IoT"
    vlan_id    = 50
    subnet     = "${VLAN_IOT_SUBNET}"
    dhcp_start = "${VLAN_IOT_DHCP_START}"
    dhcp_stop  = "${VLAN_IOT_DHCP_STOP}"
    purpose    = "corporate"
  }
  guest = {
    name       = "Guest"
    vlan_id    = 60
    subnet     = "${VLAN_GUEST_SUBNET}"
    dhcp_start = "${VLAN_GUEST_DHCP_START}"
    dhcp_stop  = "${VLAN_GUEST_DHCP_STOP}"
    purpose    = "guest"
  }
  lab = {
    name       = "Lab"
    vlan_id    = 70
    subnet     = "${VLAN_LAB_SUBNET}"
    dhcp_start = "${VLAN_LAB_DHCP_START}"
    dhcp_stop  = "${VLAN_LAB_DHCP_STOP}"
    purpose    = "corporate"
  }
}

wifi_trusted_password = "${WIFI_TRUSTED_PASSWORD}"
wifi_iot_password     = "${WIFI_IOT_PASSWORD}"
wifi_guest_password   = "${WIFI_GUEST_PASSWORD}"

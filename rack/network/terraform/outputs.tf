
output "dns_records" {
  description = "Created DNS host records"
  value = merge(
    {
      proxmox_node_one = {
        name    = unifi_dns_host_record.proxmox_node_one.name
        address = unifi_dns_host_record.proxmox_node_one.address
        type    = unifi_dns_host_record.proxmox_node_one.type
      },
      proxmox_node_two = {
        name    = unifi_dns_host_record.proxmox_node_two.name
        address = unifi_dns_host_record.proxmox_node_two.address
        type    = unifi_dns_host_record.proxmox_node_two.type
      }
    },
    {
      for k, v in unifi_dns_host_record.additional : k => {
        name    = v.name
        address = v.address
        type    = v.type
      }
    }
  )
}

output "networks" {
  description = "Created network configurations"
  value = {
    for k, v in unifi_network.networks : k => {
      id          = v.id
      name        = v.name
      subnet      = v.subnet
      vlan_id     = v.vlan_id
      dhcp_enabled = v.dhcp_enabled
    }
  }
}

output "firewall_rules" {
  description = "Configured firewall rules"
  value = {
    for k, v in unifi_firewall_rule.rules : k => {
      name     = v.name
      action   = v.action
      ruleset  = v.ruleset
      enabled  = v.enabled
    }
  }
  sensitive = false
}

output "wifi_networks" {
  description = "Configured WiFi networks (SSIDs)"
  value = {
    for k, v in unifi_wlan.wifi : k => {
      id          = v.id
      name        = v.name
      security    = v.security
      is_guest    = v.is_guest
      hide_ssid   = v.hide_ssid
    }
  }
  sensitive = false
}

output "port_forwards" {
  description = "Configured port forwarding rules"
  value = {
    for k, v in unifi_port_forward.forwards : k => {
      name     = v.name
      dst_port = v.dst_port
      fwd_ip   = v.fwd_ip
      fwd_port = v.fwd_port
      protocol = v.protocol
      enabled  = v.enabled
    }
  }
}

output "static_routes" {
  description = "Configured static routes"
  value = {
    for k, v in unifi_static_route.routes : k => {
      name     = v.name
      network  = v.network
      next_hop = v.next_hop
      distance = v.distance
    }
  }
}

output "user_groups" {
  description = "Configured user groups"
  value = {
    for k, v in unifi_user_group.groups : k => {
      id                = v.id
      name              = v.name
      qos_rate_max_down = v.qos_rate_max_down
      qos_rate_max_up   = v.qos_rate_max_up
    }
  }
}

output "summary" {
  description = "Summary of configured resources"
  value = {
    total_networks      = length(unifi_network.networks)
    total_firewall_rules = length(unifi_firewall_rule.rules)
    total_wifi_networks = length(unifi_wlan.wifi)
    total_port_forwards = length(unifi_port_forward.forwards)
    total_static_routes = length(unifi_static_route.routes)
    total_user_groups   = length(unifi_user_group.groups)
    controller_url      = var.unifi_api_url
    site               = var.unifi_site
  }
}

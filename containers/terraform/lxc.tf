resource "proxmox_virtual_environment_file" "ubuntu_container_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "pve"

  source_file {
    path = "http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  }
}

resource "proxmox_virtual_environment_container" "portainer" {
  node_name     = "pve"
  start_on_boot = true
  unprivileged  = true
  vm_id         = 105

  cpu {
    cores = 2
  }

  memory {
    dedicated = 3096
    swap      = 3096
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 20
  }

  network_interface {
    name    = "eth1"
    bridge  = "vmbr0"
    vlan_id = 30
  }

  network_interface {
    name    = "eth2"
    bridge  = "vmbr0"
    vlan_id = 70
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_file.ubuntu_container_template.id
    type             = "ubuntu"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 10
  }

  features {
    nesting = true
  }

  mount_point {
    volume = "sre_storage"
    path   = "/mnt/local"
    size   = "100G"
  }

  mount_point {
    volume = "downloads_storage"
    path   = "/mnt/downloads"
    size   = "500G"
  }

  # mount_point {
  #   volume = "media_storage"
  #   path   = "/mnt/media"
  #   size   = "2T"
  # }

  initialization {
    hostname = "portainer"
    # eth0 - VLAN 20
    ip_config {
      ipv4 {
        address = "${var.portainer_ip}/24"
        gateway = var.network_gateway
      }
    }

    # eth1 - VLAN 30
    ip_config {
      ipv4 {
        address = "${var.media_ip}/24"
      }
    }

    # eth2 - VLAN 40
    ip_config {
      ipv4 {
        address = "${var.downloads_ip}/24"
      }
    }

    user_account {
      keys     = [file(var.proxmox_ssh_public_key)]
      password = random_password.ubuntu_container_password.result
    }
  }

  # ────────────────────────────────────────────
  # Phase 1: Install Docker
  # ────────────────────────────────────────────
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.proxmox_ssh_private_key)
      host        = var.portainer_ip
    }

    inline = [
      "apt-get update",
      "apt-get install -y ca-certificates curl gnupg git",
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" > /etc/apt/sources.list.d/docker.list",
      "apt-get update",
      "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "systemctl stop docker",
      "mkdir -p /mnt/local/docker",
      "mv /var/lib/docker/* /mnt/local/docker/ || true",
      "echo '{\"data-root\": \"/mnt/local/docker\"}' > /etc/docker/daemon.json",
      "systemctl daemon-reexec",
      "systemctl start docker",
      "systemctl enable docker",
    ]
  }

  # ────────────────────────────────────────────
  # Phase 2: Clone repo, start stack
  # ────────────────────────────────────────────
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.proxmox_ssh_private_key)
      host        = var.portainer_ip
    }

    inline = [
      "git clone https://github.com/teaglebuilt/homelab /opt/homelab",
      "docker compose -f /opt/homelab/containers/compose.yaml up -d",
    ]
  }

  # ────────────────────────────────────────────
  # Phase 3: Systemd service for boot persistence
  # ────────────────────────────────────────────
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.proxmox_ssh_private_key)
      host        = var.portainer_ip
    }

    inline = [
      "cat > /etc/systemd/system/homelab-containers.service <<'EOF'",
      "[Unit]",
      "Description=Homelab Containers (Traefik, Portainer, Homepage)",
      "After=docker.service",
      "Requires=docker.service",
      "",
      "[Service]",
      "Type=oneshot",
      "RemainAfterExit=yes",
      "WorkingDirectory=/opt/homelab/containers",
      "ExecStart=/usr/bin/docker compose up -d",
      "ExecStop=/usr/bin/docker compose down",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "systemctl daemon-reload",
      "systemctl enable homelab-containers.service",
    ]
  }

  # ────────────────────────────────────────────
  # Phase 4: VPN env + macvlan network for downloads
  # ────────────────────────────────────────────
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.proxmox_ssh_private_key)
      host        = var.portainer_ip
    }

    inline = [
      "cat > /opt/homelab/platform/downloads/.env <<'DOTENV'",
      "VPN_SERVICE_PROVIDER=${var.vpn_service_provider}",
      "WIREGUARD_PRIVATE_KEY=${var.wireguard_private_key}",
      "WIREGUARD_ADDRESSES=${var.wireguard_addresses}",
      "WIREGUARD_ENDPOINT_IP=${var.wireguard_endpoint_ip}",
      "WIREGUARD_ENDPOINT_PORT=${var.wireguard_endpoint_port}",
      "WIREGUARD_PUBLIC_KEY=${var.wireguard_public_key}",
      "VPN_PORT_FORWARDING=${var.vpn_port_forwarding}",
      "VPN_PORT_FORWARDING_PROVIDER=${var.vpn_port_forwarding_provider}",
      "DOTENV",
      "chmod 600 /opt/homelab/platform/downloads/.env",

      "docker network create -d macvlan --subnet=10.0.40.0/24 --gateway=10.0.40.1 -o parent=eth2 downloads || true",
    ]
  }
}
  # ────────────────────────────────────────────
  # Phase 5: Systemd services for media + downloads stacks
  # ────────────────────────────────────────────
#   provisioner "remote-exec" {
#     connection {
#       type        = "ssh"
#       user        = "root"
#       private_key = file(var.proxmox_ssh_private_key)
#       host        = var.portainer_ip
#     }

#     inline = [
#       "cat > /etc/systemd/system/docker-network-downloads.service <<'EOF'",
#       "[Unit]",
#       "Description=Create Docker macvlan network on VLAN 40",
#       "After=docker.service",
#       "Requires=docker.service",
#       "",
#       "[Service]",
#       "Type=oneshot",
#       "RemainAfterExit=yes",
#       "ExecStart=/usr/bin/docker network create -d macvlan --subnet=10.0.40.0/24 --gateway=10.0.40.1 -o parent=eth2 downloads",
#       "ExecStop=/usr/bin/docker network rm downloads",
#       "",
#       "[Install]",
#       "WantedBy=multi-user.target",
#       "EOF",

#       "cat > /etc/systemd/system/downloads-stack.service <<'EOF'",
#       "[Unit]",
#       "Description=Downloads Stack (Gluetun + qBittorrent)",
#       "After=docker-network-downloads.service",
#       "Requires=docker-network-downloads.service",
#       "",
#       "[Service]",
#       "Type=oneshot",
#       "RemainAfterExit=yes",
#       "WorkingDirectory=/opt/homelab/platform/downloads",
#       "ExecStart=/usr/bin/docker compose up -d",
#       "ExecStop=/usr/bin/docker compose down",
#       "",
#       "[Install]",
#       "WantedBy=multi-user.target",
#       "EOF",

#       "cat > /etc/systemd/system/media-stack.service <<'EOF'",
#       "[Unit]",
#       "Description=Media Stack (Plex, Sonarr, Radarr, Prowlarr, Overseerr)",
#       "After=docker.service",
#       "Requires=docker.service",
#       "",
#       "[Service]",
#       "Type=oneshot",
#       "RemainAfterExit=yes",
#       "WorkingDirectory=/opt/homelab/platform/media",
#       "ExecStart=/usr/bin/docker compose up -d",
#       "ExecStop=/usr/bin/docker compose down",
#       "",
#       "[Install]",
#       "WantedBy=multi-user.target",
#       "EOF",

#       "systemctl daemon-reload",
#       "systemctl enable docker-network-downloads.service",
#       "systemctl enable downloads-stack.service",
#       "systemctl enable media-stack.service",
#       "systemctl start docker-network-downloads.service",
#       "systemctl start downloads-stack.service",
#       "systemctl start media-stack.service",
#     ]
#   }
# }

resource "random_password" "ubuntu_container_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

output "ubuntu_container_password" {
  value     = random_password.ubuntu_container_password.result
  sensitive = true
}

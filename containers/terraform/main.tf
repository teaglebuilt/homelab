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
    dedicated = 4096
    swap      = 3096
  }

  network_interface {
    name = "eth0"
  }

  network_interface {
    name    = "eth1"
    bridge  = "vmbr0"
    vlan_id = 7
  }

  network_interface {
    name    = "eth2"
    bridge  = "vmbr0"
    vlan_id = 8
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

  initialization {
    hostname = "portainer"

    ip_config {
      ipv4 {
        address = "${var.portainer_ip}/24"
        gateway = var.network_gateway
      }
    }

    ip_config {
      ipv4 {
        address = "${var.downloads_ip}/24"
      }
    }

    ip_config {
      ipv4 {
        address = "${var.media_ip}/24"
      }
    }

    user_account {
      keys     = [file(var.proxmox_ssh_public_key)]
      password = random_password.ubuntu_container_password.result
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.proxmox_ssh_private_key)
      host        = var.portainer_ip
    }

    inline = [
      "apt update && sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git direnv",
      "mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null",
      "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu focal stable' | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "systemctl enable --now docker && usermod -aG docker root"
    ]

  }

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
}

resource "null_resource" "gluetun_lxc_config" {
  depends_on = [proxmox_virtual_environment_container.portainer]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.proxmox_ssh_private_key)
    host        = var.proxmox_server_ip
  }

  provisioner "remote-exec" {
    inline = [
      "pct stop ${proxmox_virtual_environment_container.portainer.vm_id} || true",
      "grep -q 'mp0:' /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf || echo 'mp0: /mnt/pve/downloads_storage,mp=/mnt/downloads' >> /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf",
      "grep -q 'mp1:' /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf || echo 'mp1: /mnt/pve/media_storage,mp=/mnt/media' >> /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf",
      "grep -q 'lxc.cgroup2.devices.allow' /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf || echo 'lxc.cgroup2.devices.allow: c 10:200 rwm' >> /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf",
      "grep -q 'lxc.mount.entry: /dev/net' /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf || echo 'lxc.mount.entry: /dev/net dev/net none bind,create=dir' >> /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf",
      "grep -q 'lxc.cap.drop:$' /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf || echo 'lxc.cap.drop:' >> /etc/pve/lxc/${proxmox_virtual_environment_container.portainer.vm_id}.conf",
      "pct start ${proxmox_virtual_environment_container.portainer.vm_id}"
    ]
  }
}

resource "random_password" "ubuntu_container_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

output "ubuntu_container_password" {
  value     = random_password.ubuntu_container_password.result
  sensitive = true
}

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
    cores = 4
  }

  memory {
    dedicated = 8192
    swap      = 4096
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


resource "random_password" "ubuntu_container_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

output "ubuntu_container_password" {
  value     = random_password.ubuntu_container_password.result
  sensitive = true
}

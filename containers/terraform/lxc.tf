resource "proxmox_virtual_environment_file" "ubuntu_container_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "pve"

  source_file {
    path = "http://download.proxmox.com/images/system/ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
  }
}

resource "proxmox_virtual_environment_container" "portainer" {
  node_name = "pve"
  start_on_boot = "true"
  unprivileged = true
  vm_id = 105

  cpu {
    cores = 2
  }

  memory {
    dedicated = 3096
    swap = 3096
  }

  network_interface {
    name = "eth0"
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
    path   = "mnt/local"
    size = "100G"
  }

  initialization {
    hostname = "portainer"
    ip_config {
      ipv4 {
        address = "${var.portainer_ip}/24"
        gateway = var.network_gateway
      }
    }

    user_account {
      keys = [
        file(var.proxmox_ssh_public_key)
      ]
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
      "systemctl stop docker",
      "mkdir -p /mnt/local/docker",
      "mv /var/lib/docker/* /mnt/local/docker/ || true",
      "echo '{\"data-root\": \"/mnt/local/docker\"}' > /etc/docker/daemon.json",
      "systemctl daemon-reexec",
      "systemctl start docker",
      "systemctl enable docker",
      "usermod -aG docker root"
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
      "git clone https://github.com/teaglebuilt/homelab && cd homelab",
      "docker compose -f containers/compose.yaml up -d"
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

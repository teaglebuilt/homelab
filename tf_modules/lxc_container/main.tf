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
  unprivileged = false
  vm_id = var.vm_id

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap = 512
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

  initialization {
    hostname = var.hostname
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
      private_key = file("~/.ssh/terraform_pve1")
      host        = var.portainer_ip
    }
  
    inline = [
      "sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git direnv",
      # Add Docker’s official GPG key
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null",
      # Set up the repository
      "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt update",
      "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      # Ensure Docker starts
      "sudo systemctl enable --now docker",
      "sudo usermod -aG docker root"
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/terraform_pve1")
      host        = var.portainer_ip
    }

    inline = [
      <<-EOF
      docker run -d --name portainer_agent -p 9001:9001 \
          --restart=always \
          --volume /var/run/docker.sock:/var/run/docker.sock \
          --volume /var/lib/docker/volumes:/mnt/preview/docker/volumes \
          portainer/agent:2.19.4
      EOF
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
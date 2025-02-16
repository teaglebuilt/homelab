
resource "proxmox_virtual_environment_container" "portainer" {
  node_name = "pve"
  start_on_boot = "true"

  disk {
    file_id = "local:vztmpl/ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
  }

  network_interface {
    name = "eth0"
  }

  initialization {
    hostname = "portainer"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git direnv",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -",
      "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'",
      "apt-cache policy docker-ce",
      "rm /var/cache/apt/archives/lock && rm /var/lib/dpkg/lock*",
      "apt install -y docker-ce",
      "echo 'eval $ (direnv hook bash)' >> ~/.bashrc && source ~/.bashrc"
    ]
  }

  provisioner "remote-exec" {
      command = <<EOF
      docker run -d --name portainer_agent -p 9001:9001 \
          --restart=always \
          --volume /var/run/docker.sock:/var/run/docker.sock \
          --volume /var/lib/docker/volumes:/mnt/preview/docker/volumes \
          portainer/agent:2.19.4
      EOF
  }
}

resource "time_sleep" "wait_60_sec" {
  depends_on = [proxmox_virtual_environment_container.portainer]
  create_duration = "60s"
}

resource "null_resource" "provisioning" {
  depends_on = [time_sleep.wait_60_sec, proxmox_virtual_environment_container.portainer]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/pve")
    host        = var.portainer_ip
  }

  provisioner "file" {
    source = var.compose_file_path
    destination = "/root/compose.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker compose -f compose.yaml up -d"
    ]
  }
}
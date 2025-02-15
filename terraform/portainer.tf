
resource "proxmox_lxc" "lxc-portainer" {
  hostname = "portainer"
  ostemplate = "local:vztmpl/ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
  password = var.portainer_password
  target_node = "pve"
  start = true
  unprivileged = true

  network {
    name = "eth0"
    bridge = "vmbr0"
    ip = var.ip_address
    ip6 = "dhcp"
    gw = var.network_gateway
  }

  cores = 2
  cpuunits = 4098
  memory = 9062

  features {
    nesting = true
  }

  rootfs {
    storage = "local-lvm"
    size    = "64G"
  }

  connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/pve")
      host        = var.ip_address
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
      "echo 'eval "$(direnv hook bash)"' >> ~/.bashrc && source ~/.bashrc"
    ]
  }

  provisioner "remote-exec" {
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

resource "time_sleep" "wait_60_sec" {
  depends_on = [proxmox_lxc.lxc-docker]
  create_duration = "60s"
}

resource "null_resource" "provisioning" {
  depends_on = [time_sleep.wait_60_sec, proxmox_lxc.lxc-docker]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/pve")
    host        = var.ip_address
  }

  provisioner "file" {
    source = var.compose_file_path
    destination = "/root/compose.preview.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker network create realview && cd /root",
      "docker compose -f ./platform/compose.preview.yaml up -d",
      "docker compose -f compose.preview.yaml up -d"
    ]
  }
}
module "lxc_container" {
  source = "../../tf_modules/lxc_container"
  # source = "git::https://github.com/teaglebuilt/homelab.git//tf_modules/talos_cluster?ref=terraform_talos"
  hostname = "portainer"

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
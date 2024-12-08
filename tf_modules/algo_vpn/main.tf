resource "local_file" "algo_config" {
  content = templatefile("${path.module}/algo-config.tmpl", {
    user_name      = var.user_name
    wireguard_port = var.wireguard_port
  })
  filename = "${path.module}/algo-config.yaml"
}

resource "null_resource" "provision_algo" {
  depends_on = [local_file.algo_config]

  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.server_user
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    source      = local_file.algo_config.filename
    destination = "/home/${var.server_user}/algo-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update && sudo apt install -y python3-pip git",
      "git clone https://github.com/trailofbits/algo.git",
      "cd algo && python3 -m pip install -r requirements.txt",
      "cd algo && ./algo --auto --config /home/${var.server_user}/algo-config.yaml"
    ]
  }
}
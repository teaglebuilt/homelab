resource "linode_instance" "linode_server" {
  label       = "vpn-server"
  region      = var.region
  type        = var.instance_type
  image       = "linode/ubuntu22.04"
  root_pass   = var.root_password

  authorized_keys = [tls_private_key.ssh_key.public_key_openssh]

  tags = ["vpn"]
}

module "algo_vpn" {
  source           = "https://github.com/teaglebuilt/homelab//tf_modules/algo_vpn?ref=main"
  server_ip        = linode_instance.algo_vpn_server.ip_address
  server_user      = var.server_user
  private_key_path = local_file.private_key.filename
  user_name        = var.user_name
  wireguard_port   = var.wireguard_port
}

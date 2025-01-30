output "server_ip" {
  value = linode_instance.algo_vpn_server.ip_address
}

output "algo_config_path" {
  value = module.algo_vpn.algo_config_path
}
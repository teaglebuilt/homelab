resource "proxmox_virtual_environment_metrics_server" "influxdb_server" {
  name   = "proxmox-metrics-server"
  server = var.portainer_ip
  port   = 8089
  type   = "influxdb"
}
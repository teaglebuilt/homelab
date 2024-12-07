# output "control_plane_configs" {
#   value = { for ip, config in data.talos_machine_configuration.control_planes : ip => config.yaml }
# }
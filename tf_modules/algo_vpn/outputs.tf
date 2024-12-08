output "algo_config_path" {
  description = "The local path to the generated AlgoVPN configuration file."
  value       = local_file.algo_config.filename
}
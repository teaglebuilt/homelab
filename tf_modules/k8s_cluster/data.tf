
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_machine_configuration" "control_planes" {
  for_each            = toset(var.control_plane_ips)
  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${each.value}:6443"
  machine_type         = "controlplane"
  talos_version        = talos_machine_secrets.this.talos_version
  machine_secrets      = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "workers" {
  for_each            = toset(var.worker_ips)
  cluster_name         = var.cluster_name
  cluster_endpoint     = "https://${each.value}:6443"
  machine_type         = "controlplane"
  talos_version        = talos_machine_secrets.this.talos_version
  machine_secrets      = talos_machine_secrets.this.machine_secrets
}


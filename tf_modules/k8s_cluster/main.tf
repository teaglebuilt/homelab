resource "talos_machine_secrets" "this" {}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  node         = var.node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_machine_configuration_apply" "this" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = var.node_ip
}
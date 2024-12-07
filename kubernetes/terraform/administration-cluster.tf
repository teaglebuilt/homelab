
module "k8s_administration_cluster" {
  source = "github.com/teaglebuilt/homelab//tf_modules/k8s_cluster?ref=master"
  # source = "github.com/teaglebuilt/homelab//tf_modules/k8s_cluster?ref=v0.0.1"

  cluster_name = var.cluster_name
  control_plane_ips = var.control_plane_ips
  worker_ips = var.worker_ips
}
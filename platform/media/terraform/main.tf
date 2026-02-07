resource "portainer_stack" "media" {
  name            = "media"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.portainer_endpoint_id

  stack_file_content = file("${path.module}/../compose.yaml")

  env {
    name  = "PLEX_CLAIM"
    value = var.plex_claim
  }
}

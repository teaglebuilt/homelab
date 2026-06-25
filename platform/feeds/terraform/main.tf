resource "portainer_stack" "rss" {
  name            = "rss"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.portainer_endpoint_id

  stack_file_content = file("${path.module}/../compose.yaml")

  env {
    name  = "FRESHRSS_BASE_URL"
    value = var.freshrss_base_url
  }

  env {
    name  = "FRESHRSS_DEFAULT_USER"
    value = "admin"
  }

  env {
    name  = "FRESHRSS_DEFAULT_PASSWORD"
    value = var.freshrss_default_password
  }
}

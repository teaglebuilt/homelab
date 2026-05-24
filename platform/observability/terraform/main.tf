resource "portainer_stack" "observability" {
  name            = "observability"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.portainer_endpoint_id

  stack_file_content = file("${path.module}/../compose.yaml")

  env {
    name  = "GRAFANA_USERNAME"
    value = var.grafana_username
  }

  env {
    name  = "GRAFANA_PASSWORD"
    value = var.grafana_password
  }

  env {
    name  = "INFLUXDB_ADMIN_USERNAME"
    value = var.influxdb_admin_username
  }

  env {
    name  = "INFLUXDB_ADMIN_PASSWORD"
    value = var.influxdb_admin_password
  }

  env {
    name  = "INFLUXDB_ADMIN_TOKEN"
    value = var.influxdb_admin_token
  }

  env {
    name  = "INFLUXDB_ORG"
    value = var.influxdb_org
  }

  env {
    name  = "INFLUXDB_BUCKET"
    value = var.influxdb_bucket
  }

  env {
    name  = "INFLUXDB_DB"
    value = var.influxdb_db
  }

  env {
    name  = "GRAYLOG_PASSWORD_SECRET"
    value = var.graylog_password_secret
  }

  env {
    name  = "GRAYLOG_ROOT_PASSWORD_SHA"
    value = var.graylog_root_password_sha
  }

  env {
    name  = "UNIFI_USER"
    value = var.unifi_user
  }

  env {
    name  = "UNIFI_PASS"
    value = var.unifi_pass
  }

  env {
    name  = "UNIFI_NETWORK_GATEWAY"
    value = var.unifi_network_gateway
  }
}

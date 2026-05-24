variable "portainer_ip" {
  description = "IP address of the Portainer instance"
  type        = string
}

variable "portainer_api_key" {
  description = "Portainer API key for authentication"
  type        = string
  sensitive   = true
}

variable "portainer_endpoint_id" {
  description = "Portainer environment/endpoint ID (default local environment is 1)"
  type        = number
  default     = 3
}

variable "grafana_username" {
  description = "Grafana username"
  type        = string
}

variable "grafana_password" {
  description = "Grafana password"
  type        = string
  sensitive   = true
}

variable "influxdb_admin_username" {
  description = "InfluxDB admin username"
  type        = string
}

variable "influxdb_admin_password" {
  description = "InfluxDB admin password"
  type        = string
  sensitive   = true
}

variable "influxdb_admin_token" {
  description = "InfluxDB admin token"
  type        = string
  sensitive   = true
}

variable "influxdb_org" {
  description = "InfluxDB organization"
  type        = string
  default     = "homelab"
}

variable "influxdb_bucket" {
  description = "InfluxDB bucket"
  type        = string
  default     = "hardware"
}

variable "influxdb_db" {
  description = "InfluxDB database name used by Unpoller"
  type        = string
  default     = "hardware"
}

variable "graylog_password_secret" {
  description = "Graylog password secret"
  type        = string
  sensitive   = true
}

variable "graylog_root_password_sha" {
  description = "Graylog root password SHA"
  type        = string
  sensitive   = true
}

variable "unifi_user" {
  description = "UniFi controller username for Unpoller"
  type        = string
  default     = ""
}

variable "unifi_pass" {
  description = "UniFi controller password for Unpoller"
  type        = string
  sensitive   = true
  default     = ""
}

variable "unifi_network_gateway" {
  description = "UniFi controller URL for Unpoller"
  type        = string
  default     = ""
}

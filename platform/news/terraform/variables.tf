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
  description = "Portainer environment/endpoint ID"
  type        = number
  default     = 3
}

variable "freshrss_base_url" {
  description = "Public base URL for FreshRSS"
  type        = string
  default     = "http://localhost:8080"
}

variable "freshrss_default_password" {
  description = "Default admin user password for FreshRSS"
  type        = string
  sensitive   = true
}

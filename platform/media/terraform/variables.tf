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

variable "plex_claim" {
  description = "Plex claim token for server registration"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account tag that owns the homelab_external tunnel."
  type        = string
  default     = "ce70bbe5880cef2c1874b61b39a55436"
}

variable "homelab_external_tunnel_id" {
  description = "ID of the existing homelab_external cloudflared tunnel."
  type        = string
  default     = "862aefa7-f9b9-4c2d-be08-d3911716c583"
}

variable "mlops_external_gateway_ip" {
  description = "Pinned LB IP of the mlops homelab-external-gateway (Cilium LB-IPAM)."
  type        = string
  default     = "192.168.2.201"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab_external" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.homelab_external_tunnel_id

  config = {
    ingress = [
      # n8n on mlops — public OAuth callback host. First match wins.
      {
        hostname = "n8n.teaglebuilt.tech"
        service  = "https://${var.mlops_external_gateway_ip}"
        origin_request = {
          no_tls_verify      = true
          origin_server_name = "n8n.teaglebuilt.tech"
        }
      },
      # Required catch-all (cloudflared rejects a config without a final
      # hostname-less rule).
      {
        service = "http_status:404"
      },
    ]
  }
}

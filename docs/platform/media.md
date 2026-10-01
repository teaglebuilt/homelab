# Media

The media and download stacks run as Docker Compose, not on Kubernetes. Each `compose.yaml` is
pushed to Portainer as a standalone stack by a Terraform `portainer_stack` resource.

## Where it runs

| Stack | Services | Host | Compose file | Deployed by |
|-------|----------|------|--------------|-------------|
| `media` | Plex, Overseerr, Sonarr, Radarr, Prowlarr, FlareSolverr | Portainer LXC | `platform/media/compose.yaml` | `platform/media/terraform/main.tf` |
| `downloads` | Gluetun (VPN egress), qBittorrent | Portainer LXC | `platform/downloads/compose.yaml` | `platform/downloads/terraform/main.tf` |

The Portainer host is the `portainer` LXC container (VMID 105 on Proxmox host `pve`), defined in
`containers/terraform/main.tf`. Each stack targets Portainer endpoint `var.portainer_endpoint_id`,
whose description in the variables file calls `1` the default local environment.

qBittorrent shares Gluetun's network namespace, so its traffic leaves only through the VPN.
`task platform:downloads:test_connection` (`platform/downloads/Taskfile.yml`) checks this by fetching `ipinfo.io`
from inside `downloads:gluetun`.

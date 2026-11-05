# ADR-0002: OpenWebUI is internal-only; the LAN is not a trust boundary

## Status
Accepted

## Context
OpenWebUI holds chat history, notes, user memory, and tool connections with access to the agent platform. The owner requires it never be reachable from the internet. A config review (2026-10-06) found it is enforced at four independent layers: the Terraform-managed tunnel ingress (n8n only + 404), public external-dns reading only CRDs, route attachment only to `homelab-internal-gateway`, and the external gateway's per-host listeners and namespace label. However, agent desktops (Proxmox VMs) and agent sandboxes running arbitrary code will live on the same LAN.

## Decision Drivers
* **Must** never be published via tunnel, public DNS, or the external gateway
* **Must** resist LAN-resident untrusted code (desktops, sandboxes)
* **Should not** require an IdP while there is one human user

## Considered Options
### Option 1: Internal-only by network placement alone
- **Pros**: nothing to do
- **Cons**: treats desktops and sandboxes as trusted LAN clients
### Option 2: Internal-only plus in-cluster and app-level hardening
- **Pros**: holds even when LAN hosts are hostile
- **Cons**: a CNP and several env settings to maintain
### Option 3: Add an IdP + forward-auth in front of OpenWebUI
- **Pros**: verified identity end to end
- **Cons**: a new critical service for one user; solves a problem that doesn't exist yet

## Decision
We will use **Option 2**.

## Rationale
The realistic threat after the desktop rollout is lateral, not inbound from the internet.

## Consequences
### Positive
- Clear invariants that CI can check
- No IdP to operate
### Negative
- User identity outside Session-auth tool servers remains asserted
- A second human user or gateway-verified identity reopens Option 3

## Implementation Notes
- Route hostnames: `openwebui.homelab.internal` only (drop `openwebui.teaglebuilt.tech` unless devices lack the homelab CA)
- Remove the dormant `*.teaglebuilt.tech` ingress rule from `kubernetes/apps/networking/cloudflare/cloudflare-tunnel.yaml.gotmpl`
- Env: `ENABLE_SIGNUP=false`, `ENABLE_COMMUNITY_SHARING=false`, `ENABLE_VERSION_UPDATE_CHECK=false`, `CORS_ALLOW_ORIGIN=https://openwebui.homelab.internal`, secure + `lax` session cookies, finite `JWT_EXPIRES_IN`
- CiliumNetworkPolicy: `open-webui` ingress only from internal gateway Envoy (+ same-namespace callers)
- Proxmox desktop VLAN: deny the internal gateway VIP except the AI-gateway path
- Proposed invariant INV-S: "No OpenWebUI hostname appears in tunnelHostnames, cloudflare_tunnel.tf, any DNSEndpoint, or a route parented to homelab-external-gateway; `ai` namespace never carries homelab.io/public-ingress"
- Re-open triggers: a second human user; gateway-verified identity; any harness `channels:` that bridges a public messenger to the same agents

## Related Decisions
- ADR-0007

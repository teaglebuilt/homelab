# Plan: n8n External OAuth Callbacks Across ClusterMesh

**Status:** Ready to implement
**Date:** 2026-07-26
**Goal:** Restore external OAuth callbacks (Google Sheets first, all future providers next) to n8n at `n8n.teaglebuilt.tech`, broken by the move to ClusterMesh.

## Recommendation

**The prior conclusion is now wrong.** "Do nothing, it's a Google Console issue" was correct for the single-cluster topology, but moving the front door to ClusterMesh **stranded n8n's OAuth route on the wrong cluster.** This is a topological break, not a Google config break.

Fix it with a **one-rule tunnel change (Option B)** — do **not** add a per-namespace gateway or a dedicated "oauth callback" gateway.

## Current state and evidence (verified live, 2026-07-25)

- **Front door (Cloudflare tunnel + public external-dns) runs ONLY on `application`.** `cloudflare-tunnel` = 2 pods on application/kube-system; **none on mlops**. Set by `enable.frontDoor: true` (application) / `false` (mlops) in `kubernetes/clusters/*/environment.yaml`, consumed at `kubernetes/helmfile.d/02-core.gotmpl.yaml:35-58`.
- **n8n runs ONLY on `mlops`** (`automation` ns, pinned `mlops-work-01`; Taskfile is "mlops-only"). There is **no `automation` namespace on application**.
- The tunnel sends `*.teaglebuilt.tech` → `cilium-gateway-homelab-external-gateway` = the **application** gateway (192.168.2.242).
- `n8n-external-route` (host `n8n.teaglebuilt.tech`, path `/rest/oauth2-credential/`) exists **only on mlops**, attached to the **mlops** gateway (192.168.2.201) — which the tunnel never touches. Application has **no** n8n route.

So today: Google → CF edge → tunnel(application) → application gateway → **no route for n8n.teaglebuilt.tech → 404.** The route + service that answer it are on mlops. That is exactly why "zero callbacks since the migration."

ClusterMesh is healthy (mlops↔application, 3/3 nodes, KVStoreMesh on) with a live global-service precedent: `observability/otel-collector-mesh`.

## Direct answers to the questions asked

- **Keep `n8n.teaglebuilt.tech`?** Yes. The wildcard cert + wildcard tunnel ingress already cover it; no DNS/cert change on either option.
- **Own gateway for `automation`, or a dedicated oauth gateway?** No to both. `homelab-external-gateway` already has `allowedRoutes.namespaces.from: All`. A new Gateway = another Envoy pod + LB IP + tunnel entry for zero isolation benefit on a single-tenant homelab. The problem is **cross-cluster bridging**, not routing scope.
- **Cloudflare Access in front?** No. OAuth callbacks arrive from Google/Slack/etc as external POSTs without a CF Access session cookie → Access 302s them to login → callback dies. Only fix would be a path bypass on `/rest/oauth2-credential/*` — which the current split-host already achieves.

## The fork: how the single front door (application) reaches n8n (mlops)

### Option B — RECOMMENDED (smallest, robust)

Add a **specific** tunnel ingress rule for `n8n.teaglebuilt.tech` **above** the wildcard, targeting the mlops external gateway LB IP. Reuses the existing, already-Accepted mlops route + service **verbatim** — they resolve locally on mlops with a real EndpointSlice, so there's no cross-cluster endpoint-discovery risk.

In `kubernetes/apps/networking/cloudflare/cloudflare-tunnel.yaml.gotmpl`, before the existing `*.teaglebuilt.tech` / apex rules:

```yaml
- hostname: n8n.teaglebuilt.tech
  service: https://192.168.2.201            # mlops external gateway LB IP
  originRequest:
    noTLSVerify: true
    originServerName: n8n.teaglebuilt.tech
```

Path: Google → tunnel(application) → 192.168.2.201 (mlops gateway) → `n8n-external-route`(mlops) → n8n pod. Works because application tunnel pods and the mlops gateway share the L2 (192.168.2.0/24); .201 is an L2-announced LB IP reachable over the LAN. TLS terminates on the mlops wildcard cert; SNI `n8n.teaglebuilt.tech` selects the `https-wildcard` listener. cloudflared is first-match-wins, so the n8n rule must precede the wildcard.

**Pin the mlops gateway IP** so .201 can't drift — annotate the mlops `homelab-external-gateway` service with the Cilium LB-IPAM IP pin (verify the exact key — `io.cilium/lb-ipam-ips` vs `lbipam.cilium.io/ips` — against installed Cilium 1.18.11), or reserve it in `kubernetes/apps/networking/cilium/overlays/mlops/ip-pool.yaml`.

**Tradeoff (honest):** this puts one per-app hostname pin in tunnel config — a minor deviation from the runbook's "all per-app routing lives in Gateway API, not tunnel config." Proportionate for one workload split across the mesh; anything larger would argue for Option A.

### Option A — "purer" but needs a refactor + a verification spike (defer)

Keep the tunnel generic; instead federate `n8n-service` as a Cilium global service (mirror `otel-collector-mesh`: annotate mlops `n8n-service` global, add an `automation` ns + selectorless global `n8n-service` + the `n8n-external-route` on the **application** cluster).

Two real costs:

1. **Documented same-repo hazard:** `platform/observability/kubernetes/apps/opentelemetry/overlays/mlops/kustomization.yaml` warns that Envoy-style consumers doing their own endpoint discovery "can't see Cilium global-service backends (those live only in the eBPF datapath, not the K8s EndpointSlice)." The application gateway's Envoy may see **zero** backends for a selectorless global service and fail silently. Cilium's own Gateway *might* resolve remote global endpoints on 1.18.11 (it owns the datapath), but that is **unverified** — it needs a curl spike through the application gateway before you trust it.
2. **Refactor:** the automation stack is a flat mlops-only kustomize; Option A forces restructuring it into `base` + `overlays/{mlops,application}` like the otel app, to place the route/stub on application.

Adopt Option A later, once multiple mlops workloads need public exposure and that refactor + a confirmed global-backend result pay for themselves.

## Affected files

- `kubernetes/apps/networking/cloudflare/cloudflare-tunnel.yaml.gotmpl` (Option B: the ingress rule)
- mlops `homelab-external-gateway` service or `kubernetes/apps/networking/cilium/overlays/mlops/ip-pool.yaml` (IP pin)
- `platform/automation/kubernetes/n8n/deployment.yaml` (cleanup nit: `N8N_HOST` is set twice, lines 183 and 185; second wins — drop the duplicate)
- Untouched: mlops `n8n-external-route`/`n8n-service`, the application cluster, DNS, certs.

## Ownership / Helmfile stage

- Tunnel: stage `02-core` (`cloudflare-tunnel`, `installed: enable.frontDoor`), applied on the **application** cluster.
- Gateway IP pin: Cilium LB-IPAM (stage `01-bootstrap` overlay) or a service annotation.
- SOPS: tunnel values are gotmpl reading env from `kubernetes/.env`; no new plaintext secret.

## Dependencies / ordering

None cross-release. Purely additive tunnel config on the already-running application front door; the mlops route/service are already live and Accepted.

## Risks and tradeoffs

- Option B couples one hostname to the mlops gateway IP — mitigated by the LB-IPAM pin.
- If the mlops gateway IP is ever reassigned without updating the tunnel, n8n OAuth breaks — the pin prevents this.
- Google Console config (redirect URI exactly `https://n8n.teaglebuilt.tech/rest/oauth2-credential/callback`, account in Test users if consent screen is Testing) is still required — it was never the current blocker, but it must also be correct. n8n already advertises the right callback URL (`N8N_EDITOR_BASE_URL`/`WEBHOOK_URL` = `https://n8n.teaglebuilt.tech`).

## Validation plan (Option B)

1. Render 02-core on application → tunnel config shows the n8n rule ABOVE the wildcard.
2. `kubectl -n kube-system get svc cilium-gateway-homelab-external-gateway` on mlops → still 192.168.2.201.
3. From an application node: `curl -ksv --resolve n8n.teaglebuilt.tech:443:192.168.2.201 https://n8n.teaglebuilt.tech/rest/oauth2-credential/callback` → n8n responds (not a 404 from the application gateway).
4. Public: `curl -I https://n8n.teaglebuilt.tech/rest/oauth2-credential/callback` → n8n response.
5. cloudflared logs on application show the callback hop landing (zero since the migration).
6. Run the real Google Sheets OAuth from the n8n editor end-to-end.

## Rollback plan

Remove the added ingress rule (and the IP pin) → tunnel reverts to wildcard→application gateway = today's state. Purely additive, no stateful changes.

## Developer handoff

Implement Option B:
1. Add the specific n8n ingress rule above the wildcard in `cloudflare-tunnel.yaml.gotmpl`.
2. Pin the mlops external gateway to 192.168.2.201 via LB-IPAM (confirm the annotation key on Cilium 1.18.11).
3. Drop the duplicate `N8N_HOST` in `deployment.yaml`.

Run the validation checklist, and confirm the Google Console redirect URI + test-user settings in parallel.

## 1.0.0

- init

## 1.0.1

- fix internal DNS flapping: per-cluster `txtOwnerId`/`txtPrefix` for `internal-dns` so the two clusters stop deleting each other's UniFi records
- fix duplicate `hubble.homelab.internal`: `hubbleRoute.enabled` toggle in `homelab-gateway`, off on mlops (route/DNS only — Hubble still runs on both)
- fix ClusterMesh torn down by routine syncs: `meshOverlay` gated on `enable.clusterMesh` in `01-bootstrap`
- remove duplicated `bootstrap-cluster` task in `kubernetes/Taskfile.yml`

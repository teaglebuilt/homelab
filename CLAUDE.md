# Homelab Infrastructure Repository

## What This Is

Monorepo managing a self-hosted homelab: bare-metal Kubernetes clusters on Proxmox VMs (Talos Linux), platform services via Docker Compose, and infrastructure automation via Terraform and Ansible.


## Key Technologies and Versions

- **Kubernetes**: Talos Linux clusters on Proxmox VMs
- **Networking**: Cilium CNI, kgateway v2.2.1 (Gateway API implementation), Cloudflare Tunnels
- **GitOps**: ArgoCD with ApplicationSets, Helmfile for staged deploys
- **Secrets**: SOPS with AWS KMS encryption
- **DNS**: ExternalDNS (internal + external), CoreDNS
- **Certs**: cert-manager with Cloudflare DNS validation
- **GPU**: NVIDIA device plugin + runtime class, DCGM exporter
- **WASM**: Spin operator via kwasm
- **Storage**: NFS CSI driver
- **IaC**: Terraform/OpenTofu with Proxmox provider
- **Config**: Ansible for bare-metal, Kustomize for K8s overlays
- **Task runner**: Taskfile (not Make, except kubernetes/Makefile)

## Conventions

- Helmfile stages are numbered and ordered. Dependencies between releases use `needs:`.
- Helm values files live alongside the app in `kubernetes/apps/<category>/<app>/`.
- Kustomize is used inside Helmfile hooks (`kustomize build ... | kubectl apply`) for post-install resources.
- Environment variables are sourced from `kubernetes/.env` and `containers/.env` via Taskfile dotenv.
- SOPS-encrypted secrets match `kubernetes/*` and `platform/*` path patterns.
- The homelab-gateway chart is a wrapper: it vendors kgateway CRDs + kgateway as subchart dependencies, then adds Gateway/HTTPRoute/Certificate templates on top.
- Platform services that need K8s resources put them in a `kubernetes/` subdirectory (e.g., `platform/ai/kubernetes/`).
- Node selector `kubernetes.io/hostname: mlops-work-01` is used for GPU and cert-manager workloads.

## Deployment Flow

**Command**:`task deploy-kubernetes`

- Terraform provisions Talos VMs via Proxmox
- Talos bootstraps the cluster
- Helmfile stages deploy in order (00 through 04)
- Platform services deploy via `task platform:deploy CLUSTER=$CLUSTER{admin,application,mlops}`

## Working With This Repo

- Secrets are never committed in plaintext. Use SOPS: `sops -e` to encrypt, `sops -d` to decrypt.
- Always check which Helmfile stage a release belongs to before modifying. Stage ordering matters.
- The `generated/` directory is Helmfile output. Do not edit it directly.

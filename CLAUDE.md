# Homelab Infrastructure Repository

## What This Is

Monorepo managing a self-hosted homelab: bare-metal Kubernetes clusters on Proxmox VMs (Talos Linux), platform services via Docker Compose, and infrastructure automation via Terraform and Ansible.

## Repository Layout

```
kubernetes/           # K8s cluster management
  clusters/           # Cluster definitions: mlops, application
  helmfile.d/         # Staged Helmfile deploys: 00-prepare -> 01-bootstrap -> 02-core -> 03-hardware -> 04-monitoring
  charts/             # Custom charts (homelab-gateway wraps kgateway v2.2.1)
  apps/               # Per-app configs: networking/, security/, storage/, gitops/, hardware/, monitoring/
  terraform/          # Cluster-level Terraform (Talos provisioning)
  generated/          # Helmfile-generated output (do not edit)
platform/             # Docker Compose service stacks
  ai/                 # AI platform (kagent, LLM providers, MCP backend) - has k8s/ subdir for K8s resources
  automation/         # n8n, workflow tools
  media/              # Jellyfin, *arr stack
  observability/      # Prometheus, Grafana, Loki
  data/               # Databases, data services
  rss/                # RSS aggregation
  downloads/          # Download management
terraform/            # Top-level Terraform (VPC, providers)
tf_modules/           # Reusable modules: talos_cluster, virtual_machine, algo_vpn
ansible/              # Playbooks and roles for bare-metal setup
containers/           # Local dev containers with Traefik, Terraform for container infra
docs/                 # MkDocs documentation site
.ai/context/          # AI agent context and scraped documentation
```

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

- Read `.ai/context/docs/` for scraped technology documentation before making decisions about tools used here.
- Secrets are never committed in plaintext. Use SOPS: `sops -e` to encrypt, `sops -d` to decrypt.
- Always check which Helmfile stage a release belongs to before modifying. Stage ordering matters.
- The `generated/` directory is Helmfile output. Do not edit it directly.
- Gateway API resources (Gateway, HTTPRoute, ReferenceGrant) follow the v1 spec via kgateway.

## Agentic Tools

### Live Cluster Tools (via homelab-kagent MCP server)

The `homelab-kagent` MCP server (configured in `.mcp.json`) proxies through the agentgateway in the `ai` namespace and exposes the kagent tool server. Use these tools when you need to ground architecture decisions in the actual current state of the cluster — what's really deployed, how networking is actually wired, what policies are actually enforced.

Relevant tool families:
- `kagent-tools_helm_*` — see what's actually released and at which version
- `kagent-tools_k8s_*` — get/describe/apply/delete/patch resources, get events, pod logs, exec commands
- `kagent-tools_cilium_*` — endpoint health, BPF maps, identities, IP cache, PCAP recorders, encryption state
- `kagent-tools_argo_*` — rollout list/pause/promote/set-image, gateway plugin verification

When to use these over local `kubectl`:
- Use MCP tools when you need the result inline in the conversation (e.g., to verify a change landed, inspect live state, debug a failing pod).
- Use local `kubectl` via Bash when the output is large, you need piping, or the command is destructive and you want the user to see it explicitly.
- Treat these tools as read-leaning: `k8s_get_*`, `k8s_describe_*`, `helm_get_release`, `cilium_get_endpoint_health` first; modifications only after confirming intent.

These tools talk to the same cluster as `kubectl` — changes are real. Respect the same safety rules you would for direct cluster access.

# 0001. Store provisioning secrets in a SOPS/KMS-encrypted dotenv, injected per task

- **Status:** Proposed
- **Date:** 2026-10-03
- **Deciders:** teaglebuilt
- **Tags:** security, secrets, provisioning, taskfile

## Context

`task deploy-kubernetes` gets every credential (Proxmox, Cloudflare, UniFi, AWS,
LLM provider keys) from a gitignored `.envrc` that direnv exports into every
shell opened in the repo. That causes three problems:

- `.envrc` can't be committed, so the logic in it (kubeconfig/talosconfig merge,
  gateway IP lookup, LLM backend switch) isn't versioned and can't be reproduced
  on another machine.
- Every secret sits in the environment of every process started from the shell,
  including AI agents and MCP servers that only need two of them.
- Secrets and plain config (IPs, usernames, key paths) are mixed together, so the
  file has to be treated as secret as a whole.

Constraints that apply:

- SOPS with an AWS KMS key is already used for in-repo secrets
  (`kubernetes/clusters/_shared/cilium-ca.sops.yaml`, `kubernetes/apps/secrets/*.enc.yaml`),
  so AWS IAM credentials are already the trust root ("secret zero").
- Provisioning runs before any cluster exists, so the secret store can't depend on the cluster.
- One operator, one workstation, and a public GitHub repo.
- ArgoCD is coming (`enable.gitops`, stage 05). This decision must not block it.

Out of scope: in-cluster runtime secret delivery for ArgoCD-managed apps
(a later ADR), `containers/.env`, and `platform/observability/.env`.

## Decision Drivers

1. No new trust root: decryption should need only credentials that already exist.
2. Nothing secret in any committed file in plaintext. The committed files must still be reproducible and reviewable.
3. Small blast radius: secrets appear only in the processes that need them.
4. Small change to the existing Taskfile/helmfile flow (`requiredEnv`, `{{.VAR}}`).
5. A cheap way out when ArgoCD and External Secrets arrive.

## Considered Options

1. **SOPS dotenv + existing AWS KMS key, injected via `sops exec-env` per task**
2. **AWS SSM Parameter Store (SecureString), fetched by Taskfile**
3. **Bitwarden Secrets Manager (`bws run`)**
4. **Keep `.envrc`, encrypt it whole with SOPS** (rejected early)

### 1. SOPS dotenv + KMS (chosen)

- **How it works:** `homelab.sops.env` is committed with values encrypted and key
  names in plaintext. `task secrets:run -- <task>` runs
  `sops exec-env homelab.sops.env 'task <task>'`, so only that process tree sees
  the secrets. `deploy-kubernetes` and `destroy-kubernetes` wrap themselves this way.
  Non-secret config moves to a committed `homelab.env`, which Taskfile and direnv
  load as a dotenv.
- **Good:** no new trust root (driver 1). Uses the same key, tool, and workflow as
  existing secrets. Changes are reviewed in PRs because key names diff in plaintext.
  Works offline from the cluster. Every existing `requiredEnv` and `{{.VAR}}`
  keeps working unchanged (driver 4).
- **Bad:** rotating a secret means a commit, and the history keeps every
  ciphertext. If the KMS key is compromised, every past version can be decrypted.
  Losing the KMS key or IAM access means losing every secret, so a recovery
  path is needed. Each run makes one KMS call, so it needs network access to AWS.
- **Evidence:** the tree lists SOPS as one of the three standard GitOps options
  (`tree/infrastructure/devops/gitops-workflow.md`, "Secret Management in GitOps"),
  and this repo already runs it in production for the Cilium CA.

### 2. AWS SSM Parameter Store

- **How it works:** SecureStrings under `/homelab/*`, encrypted with the same KMS key.
  Taskfile runs `aws ssm get-parameters-by-path` and exports the results.
- **Good:** same trust root. Rotation doesn't need a commit. It's the natural backend
  for External Secrets Operator later. Standard parameters are free.
- **Bad:** the values aren't in git, so there's no record in PRs of what changed.
  Fetch-and-export is custom glue code that SOPS already provides as `exec-env`.
  The tree defaults to External Secrets Operator only when "using a cloud provider",
  and this homelab isn't one (`tree/infrastructure/devops/gitops-workflow.md`).
- **Verdict:** a better runtime store than a provisioning store. Revisit in the ArgoCD ADR.

### 3. Bitwarden Secrets Manager

- **How it works:** `bws run -- task deploy-kubernetes` with a machine-account access token.
- **Good:** good UI for rotation. The free tier fits. External Secrets Operator has a provider.
- **Bad:** adds a second trust root (the `bws` access token has to live somewhere,
  and that's exactly the problem being solved). Another vendor to depend on.
  The ESO provider needs an extra `bitwarden-sdk-server` deployment plus TLS.
  Only `bw` (the password manager CLI) is installed, which is built for
  interactive sessions, not automation.
- **Verdict:** rejected on driver 1. Only worth it if secrets must be shared with people outside AWS.

### 4. Encrypt the whole `.envrc`

- Rejected: direnv can't evaluate an encrypted file, and decrypting it on load
  brings back the "everything in every shell" problem (driver 3).

## Decision

Option 1. Layout:

| File | Committed | Holds |
|---|---|---|
| `.envrc` | yes (after migration) | functions only: AWS profile, kubeconfig/talosconfig merge, gateway lookups, LLM backend switch, allowlisted shell-secret loader |
| `homelab.env` | yes | non-secret config: Proxmox hosts and users, node IPs, gateways, domain |
| `homelab.sops.env` | yes, KMS-encrypted | every credential |
| `.envrc.local` | no | per-machine overrides (`HOMELAB_AWS_PROFILE`, `HOMELAB_SHELL_SECRETS`) |
| `kubernetes/clusters/*/cluster.yaml` | yes | per-cluster addressing (LB pool, clustermesh LB). Now the only source for the Cilium LB pool |

The interactive shell receives only `HOMELAB_SHELL_SECRETS`
(default: `N8N_API_KEY UNIFI_API_KEY`, which `.mcp.json` needs). All other secrets
exist only inside `task secrets:run`.

# ADR-0003: OpenWebUI state on CNPG Postgres, fresh start, dedicated object storage

## Status
Proposed

## Context
OpenWebUI runs single-replica with SQLite on a 2Gi node-pinned local-path RWO PVC. It is becoming a store of record (notes, channels, automations, memory, function definitions) with no backup. File uploads go to S3 under prefix `openwebui` in the Terraform remote-state *backup* bucket, using AWS credentials that also reach that bucket. The instance is under 4 days old. PersistentConfig means the existing database holds config that may diverge from git.

## Decision Drivers
* **Must** have backups for OpenWebUI data
* **Must** separate chat uploads from infrastructure state
* **Should** make git-declared config authoritative at first boot

## Considered Options
### Option 1: Keep SQLite; snapshot the PVC
- **Pros**: no new database
- **Cons**: node-pinned volume; no PITR; stale DB config persists
### Option 2: CNPG Postgres, migrate SQLite history
- **Pros**: keeps about 4 days of chats
- **Cons**: one-way manual migration with no official tool; carries stale config and vectors
### Option 3: CNPG Postgres, fresh start
- **Pros**: clean config, clean vectors, CNPG backups
- **Cons**: loses about 4 days of chats and settings

## Decision
We will use **Option 3**, single replica, websocket manager in-memory (no Redis).

## Rationale
The history is tiny, and the embedder change (ADR-0005) forces a vector reset anyway.

## Consequences
### Positive
- Backups and PITR via the existing CNPG cluster in `data`
- No uploads in the Terraform state backup bucket; least-privilege key
### Negative
- Chats from the old instance are only available as a JSON export
- Another database to back up; OpenWebUI is down if CNPG is down
- Multi-replica would later require Redis plus synchronized upgrades

## Implementation Notes
- `platform/data/kubernetes/apps/postgres/databases/openwebui.yaml` (pattern: n8n.yaml); `DATABASE_URL` from a SOPS secret
- Values: `websocket.manager: ""`, `websocket.redis.enabled: false`
- Dedicated S3 bucket and an IAM key scoped to it; remove `aws_homelab_remote_state_backup` references
- Cutover: export chats → deploy new → drop `open-webui_*` Qdrant collections → delete old PVC (it has `helm.sh/resource-policy: keep`)

## Related Decisions
- ADR-0004, ADR-0005

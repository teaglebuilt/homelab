#!/bin/sh

set -e

# Postgres is the source of truth. S3 backup is disaster recovery only.
# Skip import entirely if the DB already has workflows or credentials,
# so UI edits aren't clobbered by stale exports on every pod restart.
#
# Backup layout (set by cronjob-workflow-export):
#   /workflow-backup/workflows/<id>.json
#   /workflow-backup/credentials/<id>.json
#
# Older backups wrote everything to the root of /workflow-backup with workflow
# and credential files indistinguishable — we tolerate that legacy layout for
# workflows only, since importing a credential JSON as a workflow is a no-op
# but importing a workflow JSON as a credential corrupts the DB.

backup_has_files() {
  find "$1" -type f 2>/dev/null | head -1 | grep -q .
}

if ! backup_has_files /workflow-backup; then
  echo "No files in S3 backup; skipping import"
  exit 0
fi

db_workflow_count() {
  n8n list:workflow 2>/dev/null | grep -c '|' || echo 0
}

db_credential_count() {
  tmp_creds="$(mktemp)"
  if n8n export:credentials --all --output="$tmp_creds" >/dev/null 2>&1; then
    grep -o '"id":"' "$tmp_creds" 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
  rm -f "$tmp_creds"
}

wf_existing="$(db_workflow_count)"
cred_existing="$(db_credential_count)"
echo "Existing in postgres: workflows=${wf_existing} credentials=${cred_existing}"

if [ "${wf_existing}" -gt 0 ] || [ "${cred_existing}" -gt 0 ]; then
  echo "Postgres already populated; skipping import (S3 backup is DR-only)."
  echo "To force a restore from S3, scale n8n to 0, wipe the n8n schema, and redeploy."
  exit 0
fi

echo "Postgres empty; performing first-time bootstrap import from S3"

# Workflows: prefer new layout, fall back to legacy flat layout.
if [ -d /workflow-backup/workflows ]; then
  echo "Importing workflows from /workflow-backup/workflows"
  n8n import:workflow --separate --input=/workflow-backup/workflows
else
  echo "Importing workflow JSON files from /workflow-backup (legacy layout)"
  wf_count=0
  set +e
  for f in /workflow-backup/*.json; do
    [ -f "$f" ] || continue
    if n8n import:workflow --input="$f"; then
      wf_count=$((wf_count + 1))
    fi
  done
  set -e
  echo "Imported ${wf_count} workflow file(s)"
fi

# Credentials only import from the dedicated subdir to avoid mis-parsing
# legacy-layout files. If your legacy backup has credentials at the root,
# move them under /workflow-backup/credentials/ before restore.
if [ -d /workflow-backup/credentials ]; then
  echo "Importing credentials from /workflow-backup/credentials"
  n8n import:credentials --separate --input=/workflow-backup/credentials
else
  echo "No /workflow-backup/credentials/ directory; skipping credential import"
fi

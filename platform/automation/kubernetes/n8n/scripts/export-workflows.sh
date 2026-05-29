#!/bin/sh

set -e

mkdir -p /backup

backup_has_workflows() {
  find /backup -type f 2>/dev/null | head -1 | grep -q .
}

export_from_db() {
  mkdir -p /backup/workflows /backup/credentials
  n8n export:workflow --all --backup --output=/backup/workflows
  # `--backup` writes one file per credential as <output>/<id>.json.
  # Keep credentials in their own subdir so import can distinguish
  # them from workflow JSONs (n8n CLI does not).
  n8n export:credentials --all --backup --output=/backup/credentials
}

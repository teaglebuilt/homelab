#!/bin/sh

set -e

mkdir -p /backup/workflows /backup/credentials

# `--backup` writes one file per entity as <output>/<id>.json.
# Workflows and credentials go into separate subdirs so the
# import-on-bootstrap script can distinguish them (n8n CLI does not).
n8n export:workflow --all --backup --output=/backup/workflows
n8n export:credentials --all --backup --output=/backup/credentials

wf_count="$(find /backup/workflows -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
cred_count="$(find /backup/credentials -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"

if [ "${wf_count}" = "0" ] && [ "${cred_count}" = "0" ]; then
  echo "Postgres has no workflows or credentials; nothing to back up"
  exit 0
fi

echo "Backup ready: ${wf_count} workflow(s), ${cred_count} credential(s) in /backup"

#!/usr/bin/env bash
# Watches for GPUXidError NodeCondition and kicks off recover.sh.
# Also caches the PCI address periodically while the device is healthy.
set -uo pipefail

NODE="${NODE_NAME:?NODE_NAME required}"
POLL_SECONDS="${POLL_SECONDS:-15}"

log() { echo "[gpu-recovery-watch] $(date -u +%FT%TZ) $*"; }

log "watcher started for node $NODE (poll=${POLL_SECONDS}s)"

while true; do
  cond="$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="GPUXidError")].status}' 2>/dev/null || echo "")"
  if [[ "$cond" == "True" ]]; then
    reason="$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="GPUXidError")].reason}' 2>/dev/null || echo "")"
    log "GPUXidError=True reason=$reason — invoking recover.sh"
    DETECTED_XID="$reason" /scripts/recover.sh || log "recover.sh exit=$?"
  fi
  sleep "$POLL_SECONDS"
done

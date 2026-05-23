#!/usr/bin/env bash
# Watches for NVIDIA-related NodeConditions and kicks off recover.sh.
#
#   GPUXidError=True   - emitted by node-problem-detector when the custom
#                        kernel-monitor rules in npd-values.yaml match an
#                        `NVRM: Xid (PCI:...): N,` line in dmesg.
#   KernelDeadlock=True - npd built-in condition (hung_task / soft lockup).
#                        Many GPU hangs (GSP firmware lockup, the Thunderbolt
#                        fan-runaway case that just spins the fan at 100%)
#                        trip this BEFORE any Xid line is logged, so we treat
#                        it as a fallback signal AFTER confirming recent host
#                        dmesg shows an nvidia symbol in a hung-task / Call
#                        Trace block. Without that filter we'd recover the GPU
#                        for unrelated kernel deadlocks.
#
# Also caches the PCI address periodically while the device is healthy.
set -uo pipefail

NODE="${NODE_NAME:?NODE_NAME required}"
POLL_SECONDS="${POLL_SECONDS:-15}"
DMESG_LOOKBACK_LINES="${DMESG_LOOKBACK_LINES:-500}"

log() { echo "[gpu-recovery-watch] $(date -u +%FT%TZ) $*"; }
host() { nsenter -t 1 -m -u -i -n -p -- "$@"; }

condition_status() {
  kubectl get node "$NODE" \
    -o jsonpath="{.status.conditions[?(@.type==\"$1\")].status}" 2>/dev/null \
    || echo ""
}

condition_reason() {
  kubectl get node "$NODE" \
    -o jsonpath="{.status.conditions[?(@.type==\"$1\")].reason}" 2>/dev/null \
    || echo ""
}

# True only if recent host dmesg contains BOTH a hung-task/soft-lockup
# indicator AND an nvidia kernel symbol within the same lookback window.
dmesg_has_nvidia_hang() {
  local recent
  recent="$(host dmesg 2>/dev/null | tail -n "$DMESG_LOOKBACK_LINES")"
  [[ -n "$recent" ]] || return 1
  echo "$recent" | grep -Eq 'blocked for more than [0-9]+ seconds|soft lockup|hung_task' || return 1
  echo "$recent" | grep -Eiq 'nvidia|nvrm|nv_' || return 1
  return 0
}

log "watcher started for node $NODE (poll=${POLL_SECONDS}s)"

while true; do
  if [[ "$(condition_status GPUXidError)" == "True" ]]; then
    reason="$(condition_reason GPUXidError)"
    log "GPUXidError=True reason=$reason — invoking recover.sh"
    DETECTED_XID="$reason" /scripts/recover.sh || log "recover.sh exit=$?"

  elif [[ "$(condition_status KernelDeadlock)" == "True" ]]; then
    reason="$(condition_reason KernelDeadlock)"
    if dmesg_has_nvidia_hang; then
      log "KernelDeadlock=True reason=$reason and nvidia symbol in recent dmesg — invoking recover.sh"
      DETECTED_XID="kernel-deadlock:${reason:-unknown}" /scripts/recover.sh || log "recover.sh exit=$?"
    else
      log "KernelDeadlock=True reason=$reason but no nvidia symbols in recent dmesg — skipping (non-GPU deadlock)"
    fi
  fi

  sleep "$POLL_SECONDS"
done

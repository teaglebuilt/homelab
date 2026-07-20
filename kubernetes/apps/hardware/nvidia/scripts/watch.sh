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
#   fan runaway        - LEADING indicator, evaluated only when neither
#                        condition above is set. On the Thunderbolt enclosure a
#                        pegged fan precedes XID 119 (GSP loses the fan curve),
#                        so we act before the hang kills a running job:
#                          - GPU busy  -> preemptively cordon (no NEW work lands
#                                         in the blast radius); we record that WE
#                                         cordoned and undo it once the fan drops
#                                         back below FAN_RECOVER_PCT (hysteresis),
#                                         so a transient blip can't strand the node.
#                          - GPU idle  -> safe to soft-reset via recover.sh now.
#                        NB: this is firmware-hang mitigation, NOT thermal — a
#                        power-limit cap would not help here and nvidia-smi may
#                        be unresponsive once GSP is hung.
#
# Also caches the PCI address periodically while the device is healthy.
set -uo pipefail

NODE="${NODE_NAME:?NODE_NAME required}"
POLL_SECONDS="${POLL_SECONDS:-15}"
DMESG_LOOKBACK_LINES="${DMESG_LOOKBACK_LINES:-500}"
FAN_RUNAWAY_PCT="${FAN_RUNAWAY_PCT:-95}"   # cordon/reset at or above this fan %
FAN_RECOVER_PCT="${FAN_RECOVER_PCT:-85}"   # clear our preemptive cordon below this
STATE_DIR="${STATE_DIR:-/var/lib/gpu-recovery}"
FAN_CORDON_SENTINEL="$STATE_DIR/fan-cordon"
mkdir -p "$STATE_DIR"

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

# Highest fan % across all GPUs on the host. Cards without a fan sensor report
# [N/A] and are ignored; if nvidia-smi hangs (GSP wedged) the timeout yields no
# output and we return 0 — a truly hung device trips the XID/deadlock path above,
# not this leading indicator.
fan_speed() {
  timeout 8 host nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null \
    | awk '{ v=$1+0; if ($1 ~ /^[0-9]+$/ && v>m) m=v } END { print m+0 }'
}

# True if any compute application is currently resident on a GPU.
gpu_busy() {
  [[ -n "$(timeout 8 host nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null)" ]]
}

log "watcher started for node $NODE (poll=${POLL_SECONDS}s, fan_runaway=${FAN_RUNAWAY_PCT}%)"

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

  else
    # No GPU NodeCondition tripped — check the leading fan-runaway indicator.
    fan="$(fan_speed)"
    if [[ "$fan" -ge "$FAN_RUNAWAY_PCT" ]]; then
      if gpu_busy; then
        # Work in flight — never reset on a warning. Cordon so no NEW job lands,
        # and remember that WE cordoned so the hysteresis branch can undo it.
        if [[ ! -f "$FAN_CORDON_SENTINEL" ]]; then
          log "fan=${fan}% >= ${FAN_RUNAWAY_PCT}% with active compute — preemptive cordon of $NODE"
          kubectl cordon "$NODE" && : > "$FAN_CORDON_SENTINEL" || log "cordon failed"
        fi
      else
        # Fan pegged but GPU idle — safe to nudge GSP before it fully hangs.
        log "fan=${fan}% >= ${FAN_RUNAWAY_PCT}% and GPU idle — preemptive soft reset via recover.sh"
        DETECTED_XID="fan-runaway-preempt" /scripts/recover.sh || log "recover.sh exit=$?"
      fi
    elif [[ -f "$FAN_CORDON_SENTINEL" && "$fan" -lt "$FAN_RECOVER_PCT" ]]; then
      # Fan recovered and no XID materialized — undo ONLY our preemptive cordon.
      log "fan=${fan}% < ${FAN_RECOVER_PCT}% — clearing preemptive cordon on $NODE"
      kubectl uncordon "$NODE" || true
      rm -f "$FAN_CORDON_SENTINEL"
    fi
  fi

  sleep "$POLL_SECONDS"
done

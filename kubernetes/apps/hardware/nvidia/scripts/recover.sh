#!/usr/bin/env bash
# gpu-recovery action-tree executor.
# Triggered by the watcher loop when it observes:
#   - NodeCondition GPUXidError=True (set by node-problem-detector), OR
#   - An alert annotation on this node written by Alertmanager webhook.
#
# Runs the action tree: drain -> nvidia-smi -r -> pci unbind/rebind -> reboot.
# Uses nsenter into PID 1 to run host-resident binaries (nvidia-smi, lspci).
set -uo pipefail

NODE="${NODE_NAME:?NODE_NAME required}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
WINDOW_SECONDS="${WINDOW_SECONDS:-3600}"
ENABLE_NODE_REBOOT="${ENABLE_NODE_REBOOT:-false}"
NVIDIA_VENDOR="10de"
STATE_DIR="/var/lib/gpu-recovery"
mkdir -p "$STATE_DIR"

log() { echo "[gpu-recovery] $(date -u +%FT%TZ) $*"; }

host() { nsenter -t 1 -m -u -i -n -p -- "$@"; }

pci_addr() {
  # Prefer last-known address persisted when the device was healthy,
  # otherwise discover it from lspci.
  if [[ -s "$STATE_DIR/pci-addr" ]]; then
    cat "$STATE_DIR/pci-addr"
    return
  fi
  local a
  a="$(host lspci -D -d "${NVIDIA_VENDOR}:" 2>/dev/null | awk '{print $1; exit}')"
  [[ -n "$a" ]] && echo "$a" > "$STATE_DIR/pci-addr"
  echo "$a"
}

device_on_bus() {
  host lspci -D -d "${NVIDIA_VENDOR}:" 2>/dev/null | grep -q .
}

nvidia_smi_responsive() {
  timeout 10 host nvidia-smi -L >/dev/null 2>&1
}

gpu_processes() {
  timeout 10 host nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null
}

step1_drain() {
  log "step 1: drain CUDA workloads on $NODE"
  kubectl cordon "$NODE" || true
  # Evict pods using the nvidia runtime class on this node.
  local pods
  pods="$(kubectl get pods --all-namespaces \
    --field-selector "spec.nodeName=$NODE" \
    -o jsonpath='{range .items[?(@.spec.runtimeClassName=="nvidia")]}{.metadata.namespace}/{.metadata.name} {end}')"
  for p in $pods; do
    local ns="${p%%/*}"
    local name="${p##*/}"
    log "  deleting pod $ns/$name"
    kubectl delete pod -n "$ns" "$name" --grace-period=10 --timeout=30s || true
  done
  sleep 15
  if nvidia_smi_responsive && [[ -z "$(gpu_processes)" ]]; then
    log "step 1 OK — workloads cleared"
    return 0
  fi
  return 1
}

step2_smi_reset() {
  log "step 2: nvidia-smi -r"
  if ! nvidia_smi_responsive; then
    log "  device not responsive to nvidia-smi, skipping"
    return 1
  fi
  if timeout 30 host nvidia-smi -r -i 0; then
    sleep 5
    nvidia_smi_responsive && { log "step 2 OK"; return 0; }
  fi
  return 1
}

step3_pci_rebind() {
  local addr; addr="$(pci_addr)"
  if [[ -z "$addr" ]]; then
    log "step 3: no PCI address known and device not on bus — rescanning blind"
    echo 1 > /sys/bus/pci/rescan || true
    sleep 5
    if device_on_bus; then
      addr="$(pci_addr)"
    else
      log "step 3 FAIL — rescan did not bring device back"
      return 1
    fi
  fi
  log "step 3: pci unbind/remove/rescan/bind for $addr"
  # Unbind from driver (tolerate already-gone)
  echo "$addr" > /sys/bus/pci/drivers/nvidia/unbind 2>/dev/null || true
  # Remove device node
  if [[ -e "/sys/bus/pci/devices/$addr/remove" ]]; then
    echo 1 > "/sys/bus/pci/devices/$addr/remove" 2>/dev/null || true
  fi
  sleep 2
  echo 1 > /sys/bus/pci/rescan || true
  # Wait for device to reappear
  for i in $(seq 1 15); do
    if [[ -d "/sys/bus/pci/devices/$addr" ]]; then break; fi
    sleep 2
  done
  if [[ ! -d "/sys/bus/pci/devices/$addr" ]]; then
    log "step 3 FAIL — device did not reappear at $addr"
    return 1
  fi
  echo "$addr" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null || true
  sleep 5
  nvidia_smi_responsive && { log "step 3 OK"; return 0; }
  log "step 3 FAIL — device present but nvidia-smi still not responsive"
  return 1
}

step4_node_reboot() {
  if [[ "$ENABLE_NODE_REBOOT" != "true" ]]; then
    log "step 4: reboot disabled by ENABLE_NODE_REBOOT=$ENABLE_NODE_REBOOT — manual intervention required"
    return 1
  fi
  if [[ ! -f /etc/talos/talosconfig ]]; then
    log "step 4: talosconfig not mounted — cannot reboot"
    return 1
  fi
  log "step 4: talosctl reboot $NODE"
  /usr/local/bin/talosctl --talosconfig /etc/talos/talosconfig reboot --nodes "$NODE" || return 1
  return 0
}

circuit_breaker_check() {
  # Returns 0 if OK to proceed, 1 if tripped.
  local now attempts window_start elapsed
  now="$(date +%s)"
  attempts="$(kubectl get cm -n kube-system gpu-recovery-state -o jsonpath="{.data.${NODE}\.attempts}" 2>/dev/null || echo 0)"
  attempts="${attempts:-0}"
  window_start="$(kubectl get cm -n kube-system gpu-recovery-state -o jsonpath="{.data.${NODE}\.window-start}" 2>/dev/null || echo 0)"
  window_start="${window_start:-0}"
  elapsed=$(( now - window_start ))
  if (( elapsed > WINDOW_SECONDS )); then
    attempts=0
    window_start=$now
  fi
  if (( attempts >= MAX_ATTEMPTS )); then
    log "CIRCUIT BREAKER OPEN — attempts=$attempts within ${WINDOW_SECONDS}s"
    kubectl patch cm -n kube-system gpu-recovery-state --type merge \
      -p "{\"data\":{\"${NODE}.last-status\":\"circuit-open\"}}" || true
    return 1
  fi
  attempts=$((attempts + 1))
  kubectl patch cm -n kube-system gpu-recovery-state --type merge \
    -p "{\"data\":{\"${NODE}.attempts\":\"${attempts}\",\"${NODE}.window-start\":\"${window_start}\"}}" || true
  return 0
}

record_result() {
  local status="$1" xid="${2:-unknown}"
  kubectl patch cm -n kube-system gpu-recovery-state --type merge \
    -p "{\"data\":{\"${NODE}.last-status\":\"${status}\",\"${NODE}.last-xid\":\"${xid}\",\"${NODE}.last-run\":\"$(date -u +%FT%TZ)\"}}" || true
}

clear_node_condition() {
  # node-problem-detector clears the condition on its own once dmesg scan
  # window advances. We uncordon the node so new workloads can schedule.
  kubectl uncordon "$NODE" || true
}

# Cache the PCI address while we still have a healthy device.
if device_on_bus && [[ ! -s "$STATE_DIR/pci-addr" ]]; then
  pci_addr >/dev/null
fi

XID="${DETECTED_XID:-unknown}"
log "=== XID $XID recovery starting on $NODE ==="

if ! circuit_breaker_check; then
  record_result "circuit-open" "$XID"
  exit 2
fi

if step1_drain; then record_result "success" "$XID"; clear_node_condition; exit 0; fi
if step2_smi_reset; then record_result "success" "$XID"; clear_node_condition; exit 0; fi
if step3_pci_rebind; then record_result "success" "$XID"; clear_node_condition; exit 0; fi
if step4_node_reboot; then record_result "success" "$XID"; exit 0; fi

record_result "failed" "$XID"
log "=== recovery FAILED on $NODE — all steps exhausted ==="
exit 1

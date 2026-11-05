#!/usr/bin/env bash

set -euo pipefail
# Invoked by Proxmox as: <script> <vmid> <phase>
#   pre-start  — refuse start if PCI functions are missing or bound to a host
#                NVIDIA driver; bind to vfio-pci only when unbound.
#   post-stop  — unbind from vfio-pci only after QEMU has exited, and only if
#                the device is still on vfio-pci (never touch other drivers).

VMID="${1:?vmid required}"
PHASE="${2:?phase required}"

# Hard allowlist — never act on other VMs that might share this snippet.
ALLOWED_VMIDS=(102)
# RTX 4070 SUPER VGA + audio functions on pve2 (update if lspci bus address moves).
GPU_DEVICES=("0000:2e:00.0" "0000:2e:00.1")
EXPECTED_DRIVER=vfio-pci

log() {
  echo "[gpu-hook vmid=${VMID} phase=${PHASE}] $*"
}

allowed_vmid() {
  local id
  for id in "${ALLOWED_VMIDS[@]}"; do
    [[ "$id" == "$VMID" ]] && return 0
  done
  return 1
}

driver_of() {
  local dev="$1"
  if [[ -L "/sys/bus/pci/devices/${dev}/driver" ]]; then
    basename "$(readlink -f "/sys/bus/pci/devices/${dev}/driver")"
  else
    echo ""
  fi
}

qemu_still_running() {
  # Match this VM's QEMU process only.
  pgrep -f "qemu-system-x86_64.*-id ${VMID}(/| |$)" >/dev/null 2>&1 \
    || pgrep -f "/usr/bin/kvm.*-id ${VMID}(/| |$)" >/dev/null 2>&1
}

if ! allowed_vmid; then
  log "skip: VMID not in allowlist ${ALLOWED_VMIDS[*]}"
  exit 0
fi

case "$PHASE" in
  pre-start)
    for dev in "${GPU_DEVICES[@]}"; do
      if [[ ! -e "/sys/bus/pci/devices/${dev}" ]]; then
        log "ERROR: PCI device ${dev} missing — refusing start (check Thunderbolt/eGPU)"
        exit 1
      fi
      drv="$(driver_of "$dev")"
      case "$drv" in
        "$EXPECTED_DRIVER")
          log "ok: ${dev} already on ${EXPECTED_DRIVER}"
          ;;
        nvidia|nvidia_drm|nouveau|"")
          if [[ "$drv" == "nvidia" || "$drv" == "nvidia_drm" || "$drv" == "nouveau" ]]; then
            log "ERROR: ${dev} bound to host driver '${drv}' — refuse start (unbind host driver first)"
            exit 1
          fi
          log "binding unbound ${dev} to ${EXPECTED_DRIVER}"
          echo "$EXPECTED_DRIVER" >"/sys/bus/pci/devices/${dev}/driver_override"
          if ! echo "$dev" >"/sys/bus/pci/drivers/${EXPECTED_DRIVER}/bind" 2>/dev/null; then
            # Already claimed by vfio via override race — re-check.
            drv="$(driver_of "$dev")"
            if [[ "$drv" != "$EXPECTED_DRIVER" ]]; then
              log "ERROR: failed to bind ${dev} to ${EXPECTED_DRIVER} (driver='${drv:-none}')"
              exit 1
            fi
          fi
          log "bound: ${dev} -> ${EXPECTED_DRIVER}"
          ;;
        *)
          log "ERROR: ${dev} bound to unexpected driver '${drv}' — refuse start"
          exit 1
          ;;
      esac
    done
    ;;

  post-stop)
    if qemu_still_running; then
      log "skip unbind: QEMU still running for VM ${VMID}"
      exit 0
    fi
    for dev in "${GPU_DEVICES[@]}"; do
      if [[ ! -e "/sys/bus/pci/devices/${dev}" ]]; then
        log "skip: ${dev} absent"
        continue
      fi
      drv="$(driver_of "$dev")"
      if [[ "$drv" != "$EXPECTED_DRIVER" ]]; then
        log "skip unbind: ${dev} driver is '${drv:-none}', not ${EXPECTED_DRIVER}"
        continue
      fi
      log "unbinding ${dev} from ${EXPECTED_DRIVER}"
      if ! echo "$dev" >"/sys/bus/pci/devices/${dev}/driver/unbind" 2>/dev/null; then
        log "warn: unbind failed for ${dev}"
      fi
    done
    ;;

  *)
    # pre-stop / post-start / migrate phases: no-op
    exit 0
    ;;
esac

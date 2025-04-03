#!/bin/bash

VMID="$1"
PHASE="$2"

GPU_DEVICES=("0000:2e:00.0" "0000:2e:00.1")

if [ "$PHASE" == "post-stop" ]; then
    echo "Unbinding GPU from vfio-pci after VM $VMID shutdown..."
    for dev in "${GPU_DEVICES[@]}"; do
        if [ -e /sys/bus/pci/devices/$dev/driver/unbind ]; then
            echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
        fi
    done
fi

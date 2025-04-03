#!/bin/bash

check_iommu_groups() {
  # check pcie device for nvidia gpu is assigned to the right iommu group
  for group in /sys/kernel/iommu_groups/*; do
    echo "IOMMU Group $(basename "$group"):"
    for device in "$group"/devices/*; do
      lspci -nns "$(basename "$device")"
    done
    echo ""
  done
}

check_device_state() {
  lspci -s 2e:00.0 -vv
}

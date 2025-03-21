#!/bin/bash

# check pcie device for nvidia gpu is assigned to the right iommu group
for group in /sys/kernel/iommu_groups/*; do
  echo "IOMMU Group $(basename "$group"):"
  for device in "$group"/devices/*; do
    lspci -nns "$(basename "$device")"
  done
  echo ""
done

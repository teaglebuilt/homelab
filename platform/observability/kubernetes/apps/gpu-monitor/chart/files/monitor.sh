#!/bin/bash

set -ex

apk add --no-cache \
  clang llvm bpftool libbpf-dev \
  linux-headers build-base jq

clang -target bpf -O2 -Wall \
  -c /ebpf-src/gpu_monitor.bpf.c \
  -o /ebpf-build/gpu_monitor.bpf.o

# bpftool prog loadall /ebpf-build/gpu_monitor.bpf.o /sys/fs/bpf/gpu_monitor
# bpftool prog attach pinned /sys/fs/bpf/gpu_monitor tracepoint pci:pci_dev_probe

echo "Watching pinned BPF programs and trace output..."

while true; do
  echo "listing btf information"
  bpftool btf list

  echo "[eBPF] Programs pinned:"
  bpftool prog show name trace_pci_dev_p
  sleep 60
done

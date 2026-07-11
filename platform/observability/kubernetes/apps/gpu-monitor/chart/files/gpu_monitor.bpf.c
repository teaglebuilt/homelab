#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

struct trace_event_raw_pci_dev_template {
    __u64 pad;
    __u32 vendor;
    __u32 device;
    __u32 subsystem_vendor;
    __u32 subsystem_device;
    __u32 class;
    __u32 irq;
    __u64 driver;
};

// Optional: Perf event struct if you want to emit events
/*
struct {
    __uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
} events SEC(".maps");
*/

SEC("tracepoint/pci/pci_dev_probe")
int trace_pci_dev_probe(struct trace_event_raw_pci_dev_template *ctx) {
    if (ctx->vendor == 0x10de) { // NVIDIA
        bpf_printk("NVIDIA GPU PCI probe detected: device=0x%x\n", ctx->device);
    }

    return 0;
}

char LICENSE[] SEC("license") = "GPL";

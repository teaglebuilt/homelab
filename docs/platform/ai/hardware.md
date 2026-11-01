# Platform AI Hardware

`nvidia-device-plugin` is used for connecting the node to the GPU device and resource allocation for kubernetes workloads. Talos has nvidia extensions used to establish base requirements for the gpu's to work on a bare immutable image.

1. [Nvidia 4070 Super RTX Ti 12GB]()
2. [Nvidia 5090 Super RTX Ti 32GB]()

Until the second GPU lands, capacity is one card on `mlops-work-00`. Replica/node
autoscaling still does not apply. What changes with a [GPU arbiter operator](https://github.com/shrinedogg/gpu-arbiter-operator)
(adapted for this lab: vLLM vs ComfyUI / training Jobs instead of gaming sessions)
is **who steals and returns the GPU** — a reconciler instead of `task gpu:mode`.

### Approaches

**Static**

No time-slicing. Device plugin advertises `nvidia.com/gpu: 1`, so the scheduler
allows only one GPU consumer at a time; that pod owns the full 12 GB. Mode
changes are manual (`task gpu:mode` or kubectl scale) — no reconciler.

```mermaid
flowchart TD
    C[Clients] --> GW[agentgateway]
    GW -->|group 1 · vLLM Ready| V["vLLM x1 · mlops-work-00<br/>max-num-seqs ~4 · full VRAM"]
    GW -->|group 2 if unhealthy| H[Hosted OpenAI]

    DP["nvidia-device-plugin<br/>no time-slicing · 1 slot"] --> S
    S["kube-scheduler<br/>at most one nvidia.com/gpu: 1"]
    V --> S
    S --> G["RTX 4070 SUPER · exclusive"]

    J["ComfyUI / train Job"] --> S
    S -->|GPU already bound| P[Pending until vLLM scaled 0]

    V --> M["/metrics"] --> A{Need GPU for something else?}
    A -->|saturation only| R[Alert: tune model / route hosted]
    A -->|yes · operator action| T["task gpu:mode<br/>scale vLLM → 0 · start claimant"]
    T --> G
    T -->|done| B["scale vLLM → 1"]
    B --> V
```

**Dynamic**

With device-plugin [time-slicing](https://github.com/NVIDIA/k8s-device-plugin#shared-access-to-gpus-with-cuda-time-slicing)
enabled (`replicas: N` on one physical card). The scheduler sees multiple
`nvidia.com/gpu` slots; CUDA still shares one 12 GB pool. No exclusive handoff —
vLLM, ComfyUI, and train Jobs can land together and contend for VRAM.

```mermaid
flowchart TD
    C[Clients] --> GW[agentgateway]
    GW --> V["vLLM · requests nvidia.com/gpu: 1"]
    J[ComfyUI / train Job] --> S

    DP["nvidia-device-plugin<br/>time-slicing replicas: N"] --> S
    S["kube-scheduler<br/>N fake GPU slots on mlops-work-00"]
    V --> S
    S --> G["one physical RTX 4070 SUPER<br/>12 GB VRAM shared"]

    G --> T["CUDA time-slice between processes"]
    T --> R{"VRAM sum of residents?"}
    R -->|fits loosely| OK[Both run · lower throughput each]
    R -->|oversubscribe| OOM["OOM / Xid · kill or stall"]

    GW -->|optional fallback| H[Hosted OpenAI]
```

Not recommended on the 4070 while vLLM holds `--gpu-memory-utilization 0.90`.
Prefer **Static** or **Reconcile**.

**Reconcile**

Considering a custom operator to manage vram allocation like [GPU arbiter](https://github.com/shrinedogg/gpu-arbiter-operator) for inspiration. Exclusive handoff (scheduling + scale), not CUDA VRAM budgets. Default holder is vLLM; transient claimants borrow the whole card, then return it.

```mermaid
flowchart TD
    C[Clients] --> GW[agentgateway]
    GW -->|group 1 · vLLM Ready| V["vLLM x1 · mlops-work-00<br/>max-num-seqs ~4"]
    GW -->|"group 2 · vLLM scaled 0<br/>or unhealthy"| H[Hosted OpenAI]

    V --> M["/metrics + DCGM free VRAM"]
    M --> A{Saturation?}
    A -->|yes| R[Alert: tune model / prefer hosted routes]

    J["Claimant: ComfyUI or train Job<br/>scheduling gate await-vram"] --> ARB
    ARB["GPUArbiter reconciler<br/>poll ~2s"]
    ARB -->|"claimant active"| Z["scale vLLM → 0<br/>release VRAM"]
    Z --> U["ungate claimant<br/>when replicas=0 or freeMiB OK"]
    U --> G["claimant holds GPU"]
    G -->|"claimant terminal"| B["scale vLLM → 1"]
    B --> V
    H -.->|"inference stays available<br/>while GPU is borrowed"| C
```

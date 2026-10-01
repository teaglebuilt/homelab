# Built At Home

<div align="center">
  <img src="assets/homelabrack.png" alt="Homelab Rack" width="400">
  <p><em>by Dillan Teagle</em></p>
</div>

<div align="center">
    <img src="https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white">
    <img src="https://img.shields.io/badge/NVIDIA-RTX%204070%20Super-76B900?style=for-the-badge&logo=nvidia&logoColor=white" alt="NVIDIA">
    <img src="https://img.shields.io/badge/Intel%20Core_i9_10th-0071C5?style=for-the-badge&logo=intel&logoColor=white" alt="Intel">
</div>

---

## A platform for

<div class="grid cards" markdown>

- ⚙️ **Automation**

    ---

    Workflow automation support with n8n for seamless integrations and task orchestration.

    [→ Learn more](platform/workflows.md)

- 🔒 **Privacy**

    ---

    Focus on network privacy, security, and lab sandboxes for safe experimentation.

    [→ Network setup](network.md)

- 🧠 **Research**

    ---

    AI powered research with self-hosted LLMs, agents, and research tools.

    [→ AI Platform](platform/ai/index.md)

</div>

---

## Quick Links

| Section | Description |
|---------|-------------|
| [Overview](overview.md) | High-level architecture: hardware, network, clusters, platform |
| [Hardware](hardware.md) | Detailed hardware inventory |
| [Network](network.md) | Detailed network inventory |
| [Kubernetes](kubernetes.md) | Talos Linux clusters, gateways, bootstrapping |
| [AI Platform](platform/ai/index.md) | AI gateway and providers |
| [Observability](platform/observability.md) | GPU metrics and monitoring |

---

## Getting Started

This documentation covers the complete setup and configuration of my homelab infrastructure, including:

- **Proxmox virtualization** with GPU passthrough
- **Talos Linux Kubernetes clusters** with Cilium networking
- **Multi-cluster architecture** using ClusterMesh
- **AI/ML platform** with multiple LLM providers
- **GitOps workflows** with Argo CD (planned, see [Admin Cluster](kubernetes.md#admin-cluster-planned))

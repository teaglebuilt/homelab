# Built At Home

<div align="center">
  <img src="assets/homelabrack.png" alt="Homelab Rack" width="400">
  <p><em>by Dillan Teagle</em></p>
</div>

<div align="center">

![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![NVIDIA](https://img.shields.io/badge/NVIDIA-GTX4070-76B900?style=for-the-badge&logo=nvidia&logoColor=white)
![Intel](https://img.shields.io/badge/Intel%20Core_i9_10th-0071C5?style=for-the-badge&logo=intel&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo%20CD-1e0b3e?style=for-the-badge&logo=argo&logoColor=#d16044)

</div>

---

## A platform for

<div class="grid cards" markdown>

-   :material-cog-sync:{ .lg .middle } **Automation**

    ---

    Workflow automation support with n8n for seamless integrations and task orchestration.

    [:octicons-arrow-right-24: Learn more](platform/workflows.md)

-   :material-shield-lock:{ .lg .middle } **Privacy**

    ---

    Focus on network privacy, security, and lab sandboxes for safe experimentation.

    [:octicons-arrow-right-24: Network setup](network.md)

-   :material-brain:{ .lg .middle } **Research**

    ---

    AI powered research with self-hosted LLMs, agents, and research tools.

    [:octicons-arrow-right-24: AI Platform](platform/ai.md)

</div>

---

## Quick Links

| Section | Description |
|---------|-------------|
| [Overview](overview.md) | High-level architecture diagram |
| [Hardware](hardware.md) | Detailed hardware inventory |
| [Kubernetes](infra/kubernetes.md) | Talos Linux cluster setup |
| [AI Platform](platform/ai.md) | AI gateway and providers |
| [Observability](platform/observability.md) | GPU metrics and monitoring |

---

## Getting Started

This documentation covers the complete setup and configuration of my homelab infrastructure, including:

- **Proxmox virtualization** with GPU passthrough
- **Talos Linux Kubernetes clusters** with Cilium networking
- **Multi-cluster architecture** using ClusterMesh
- **AI/ML platform** with multiple LLM providers
- **GitOps workflows** with Argo CD

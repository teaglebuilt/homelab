# Kubernetes Configuration Guidelines

## Architecture Preferences

- Cilium as primary CNI with eBPF enabled
- Service mesh and BGP routing enabled
- Strict mTLS enforcement
- GPU powered node within nvidia-runtime
- Envoy AI Gateway is used as the replacement for MCP (Model Context Protocol)

## References

[Kubernetes](../../kubernetes/README.md)
[Documentation](../../docs/docs/infra/kubernetes.md)

## Security Requirements

- All secrets must use sm-operator
- Implement RBAC strictly
- Enable network policies
- Use SecurityContexts appropriately

## Storage Configuration

* Test and decide on kubernetes storage configuration
  - [x] **NFS SCI Plugin**
        Provisioning storage on the NAS Server by kubernetes defined resources..(AKA persistent volume claims)
        ```
        (UNAS Pro)  --->  (PVC) <--- (Deployment)
        ```
  - [ ]  UNAS Pro + Proxmox CSI for persistence
        Mount storage from UNAS to proxmox with and use a proxmox csi to attach storage to the cluster.
        ```
        (UNAS Pro)  --->  (Proxmox) <--- (PVC)  <--- (Deployment)
        ```

* Implement backup strategies

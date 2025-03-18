# Kubernetes Configuration Guidelines

## Architecture Preferences

- Cilium as primary CNI with eBPF enabled
- Service mesh and BGP routing enabled
- Strict mTLS enforcement
- GPU powered node within nvidia-runtime

## References

[Kubernetes](../../kubernetes/README.md)
[Documentation](../../docs/docs/infra/kubernetes.md)

## Security Requirements

- All secrets must use sm-operator
- Implement RBAC strictly
- Enable network policies
- Use SecurityContexts appropriately

## Storage Configuration

- UNAS Pro + Proxmox CSI for persistence
- Define appropriate StorageClasses
- Implement backup strategies

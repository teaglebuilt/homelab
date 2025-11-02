# Cilium CNI Configuration with Optional ClusterMesh

This directory contains the Cilium CNI configuration with support for both standalone and ClusterMesh (multi-cluster) deployments using Kustomize overlays.

## Directory Structure

```
cilium/
├── base/                          # Base configuration shared across all clusters
│   ├── values.yaml               # Base Helm values
│   ├── clustermesh-values.yaml   # ClusterMesh specific values
│   ├── ip-pool.yaml             # IP pool configuration
│   ├── announcement.yaml         # L2 announcement configuration
│   └── kustomization.yaml        # Base Kustomize configuration
│
├── overlays/                      # Cluster-specific configurations
│   ├── mlops/                    # MLOps cluster overlay
│   │   ├── values.yaml          # MLOps specific values
│   │   └── kustomization.yaml   # MLOps Kustomize configuration
│   │
│   └── administration/           # Administration cluster overlay
│       ├── values.yaml          # Administration specific values
│       └── kustomization.yaml   # Administration Kustomize configuration
│
└── README.md                      # This file
```

## Configuration Overview

### Base Configuration

The base configuration (`base/`) contains:
- **values.yaml**: Common Cilium settings for all clusters (Talos-specific settings, resource limits, Hubble configuration)
- **clustermesh-values.yaml**: ClusterMesh base settings (API server, tunnel protocol, IPAM mode)
- **ip-pool.yaml**: IP pool definitions for LoadBalancer services
- **announcement.yaml**: L2 announcement policies for bare metal deployments

### Cluster Overlays

Each cluster has its own overlay with cluster-specific settings:

#### MLOps Cluster (`overlays/mlops/`)
- Cluster ID: 2
- Pod CIDR: 10.244.0.0/20
- Custom resource limits for ML workloads

#### Administration Cluster (`overlays/administration/`)
- Cluster ID: 1
- Pod CIDR: 10.244.16.0/20
- Enhanced observability with more Hubble replicas
- Higher resource limits for management tasks

## Deployment Modes

### Standalone Mode (Single Cluster)

For deploying Cilium to a single cluster without multi-cluster features:

```yaml
# In your cluster's helmfile.yaml
values:
  - cilium:
      clusterMeshEnabled: false  # Disable ClusterMesh
      overlay: mlops  # Optional: still use overlays for cluster-specific config
      overlayPath: ../apps/networking/cilium/overlays/mlops/values.yaml
```

This mode:
- ✅ Provides full CNI functionality
- ✅ Includes Hubble observability
- ✅ Supports Gateway API and LoadBalancer
- ❌ No cross-cluster communication
- ❌ No ClusterMesh API server overhead
- ❌ No multi-cluster services

### ClusterMesh Mode (Multi-Cluster)

For connecting multiple clusters with shared services:

```yaml
# In your cluster's helmfile.yaml
values:
  - cilium:
      clusterMeshEnabled: true  # Enable ClusterMesh
      overlay: mlops
      overlayPath: ../apps/networking/cilium/overlays/mlops/values.yaml
```

This mode enables:
- ✅ All standalone features
- ✅ Cross-cluster service discovery
- ✅ Global services with `.clusterset.local` DNS
- ✅ Multi-cluster load balancing
- ✅ MCS API support (ServiceExport/ServiceImport)
- ✅ Cross-cluster network policies

## Deployment

### Prerequisites

1. Install required tools:
   ```bash
   # Helmfile
   brew install helmfile   # macOS
   # or download from https://github.com/helmfile/helmfile

   # Kustomize
   brew install kustomize   # macOS
   # or download from https://kubectl.docs.kubernetes.io/installation/kustomize/

   # Cilium CLI (optional, for cluster mesh operations)
   curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64.tar.gz{,.sha256sum}
   shasum -a 256 -c cilium-*.tar.gz.sha256sum
   sudo tar xzvfC cilium-*.tar.gz /usr/local/bin
   ```

2. Ensure kubectl contexts are configured for both clusters:
   ```bash
   kubectl config get-contexts
   ```

### Deploying Cilium

#### For Standalone Deployment

Simply set `clusterMeshEnabled: false` in your cluster's helmfile and deploy:

```bash
cd /Users/teaglebuilt/github/teaglebuilt/homelab/kubernetes/clusters/mlops
helmfile --kube-context=mlops sync
```

#### For ClusterMesh Deployment

##### Option 1: Using the Setup Script (Recommended)

```bash
# Run the interactive setup script
cd /Users/teaglebuilt/github/teaglebuilt/homelab/kubernetes
./scripts/setup-clustermesh.sh

# Select option 1 for full setup
```

#### Option 2: Manual Deployment

1. **Deploy to MLOps cluster:**
   ```bash
   cd /Users/teaglebuilt/github/teaglebuilt/homelab/kubernetes/clusters/mlops
   helmfile --kube-context=mlops sync
   ```

2. **Deploy to Administration cluster:**
   ```bash
   cd /Users/teaglebuilt/github/teaglebuilt/homelab/kubernetes/clusters/administration
   helmfile --kube-context=administration sync
   ```

3. **Enable ClusterMesh on both clusters:**
   ```bash
   cilium --context=mlops clustermesh enable --service-type LoadBalancer
   cilium --context=administration clustermesh enable --service-type LoadBalancer
   ```

4. **Connect the clusters:**
   ```bash
   cilium --context=mlops clustermesh connect --destination-context=administration
   ```

5. **Verify the connection:**
   ```bash
   cilium --context=mlops clustermesh status
   cilium --context=administration clustermesh status
   ```

## Verification

### Check Cilium Status

```bash
# MLOps cluster
cilium --context=mlops status

# Administration cluster
cilium --context=administration status
```

### Check ClusterMesh Status

```bash
# View mesh status
cilium --context=mlops clustermesh status
cilium --context=administration clustermesh status
```

### Test Cross-Cluster Connectivity

```bash
# Run connectivity test
cilium --context=mlops connectivity test --multi-cluster=administration
```

## Using ClusterMesh Features

### Global Services

To make a service available across clusters, annotate it:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-global-service
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
spec:
  # ... service spec
```

### Service Affinity

To prefer local cluster endpoints:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/affinity: "local"
spec:
  # ... service spec
```

## Customization

### Adding a New Cluster

1. Create a new overlay directory:
   ```bash
   mkdir -p overlays/new-cluster
   ```

2. Create `overlays/new-cluster/values.yaml`:
   ```yaml
   cluster:
     name: new-cluster
     id: 3  # Must be unique (1-255)

   ipam:
     operator:
       clusterPoolIPv4PodCIDRList:
         - 10.244.32.0/20  # Unique pod CIDR
   ```

3. Create `overlays/new-cluster/kustomization.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: kube-system

   bases:
     - ../../base

   configMapGenerator:
     - name: cilium-new-cluster-values
       files:
         - values.yaml
       behavior: merge
   ```

4. Update the cluster's helmfile to use the overlay.

### Modifying Cluster-Specific Settings

Edit the appropriate overlay file:
- MLOps: `overlays/mlops/values.yaml`
- Administration: `overlays/administration/values.yaml`

Then re-deploy:
```bash
helmfile --kube-context=<cluster-context> sync
```

## Troubleshooting

### Common Issues

1. **ClusterMesh API server not accessible:**
   - Check LoadBalancer service has external IP/hostname
   - Verify firewall rules allow traffic on port 2379
   - Check cluster network connectivity

2. **Pods cannot communicate across clusters:**
   - Verify cluster IDs are unique
   - Check pod CIDRs don't overlap
   - Ensure ClusterMesh is enabled on both clusters

3. **Kustomize build fails:**
   - Verify all referenced files exist
   - Check YAML syntax in values files
   - Ensure kustomize version is compatible

### Debug Commands

```bash
# Check Cilium agent logs
kubectl --context=<context> -n kube-system logs -l k8s-app=cilium

# Check ClusterMesh API server logs
kubectl --context=<context> -n kube-system logs -l k8s-app=clustermesh-apiserver

# View Cilium endpoints
cilium --context=<context> endpoint list

# Check cluster configuration
cilium --context=<context> clustermesh status --verbose
```

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [ClusterMesh Guide](https://docs.cilium.io/en/stable/network/clustermesh/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helmfile Documentation](https://helmfile.readthedocs.io/)

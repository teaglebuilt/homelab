# Cluster Bootstrapping

## Steps

1. **Phase One** - ...
2. **Phase Two** - ...

## Configuration

Each cluster has its own files in `kubernetes/clusters/{{cluster}}`.
`kubernetes/clusters/{{cluster}}/environment.yaml` is the cluster configuration file and others are values files for different phases of bootstrapping.

## Scheduling

* `homelab.teaglebuilt.dev/gpu-node=true` is set on the worker node with the gpu connection and vllm deployment uses this label instead of the default labeld by the nvidia device plugin which is `nvidia.com/gpu.present`. Problem with using that one is it can become stale.
* All AI workloads should run on `mlops` cluster and all application related workflows should run on `application` cluster. Global services marked with cilium annotations can be used for establishing cross cluster internal dns resolution.

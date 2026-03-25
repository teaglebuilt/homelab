# helmfile - Helm Release Configuration & Orchestration

Helfile is used as the primary solution for bootstraping all CRD's, helm charts, and resources needed for the cluster to function.

## Relevance to This Repo

- Responsible for bootstraping all resources needed for the cluster
- `task kubernetes:bootstrap-cluster` runs the `helmfile` proccess.
- `kubernetes/helmfile.d` contains the helmfiles in order of execution

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- Helmfile Configuration Helm Configuration
- Helm Releases
- Cluster provisioning or bootstraping applications
- Kubernetes Configuration or dependency management
- Helm chart values reference
- Upgrading helm charts

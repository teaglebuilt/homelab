## Adding New Invariants

When discovering new architectural constraints:

1. Add to this document with next available number in the appropriate category
2. Include code examples of correct and incorrect usage
3. Explain the rationale
4. Consider adding validation (CI check, lint rule, etc.)
5. Update related documentation

### Category Prefixes

| Prefix | Category |
|--------|----------|
| INV-I | Infrastructure (Terraform, Brev) |
| INV-K | Kubernetes (K3S, Helm, resources) |
| INV-S | Security (secrets, credentials) |
| INV-G | GitOps (ArgoCD, sync) |
| INV-D | Data (MinIO, LakeFS, formats) |
| INV-P | Pipeline (Dagster) |
| INV-N | NVIDIA (NIM, GPU) |
---

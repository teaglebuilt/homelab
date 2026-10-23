# Hosted Jev classification on Talos (no Ollama, ONNX, EKS, or GPU required)

This is an **isolated experiment** for your existing Talos Kubernetes cluster. It uses the upstream pinned Go Envoy ExtProc adapter from [tjorourke/solo-labs](https://github.com/tjorourke/solo-labs/tree/ff9e3cdd1da8176edc96da7dafd4b83691b360ee/agentgateway-inference-jev-routing-eks), calls the **hosted TypeSafe Jev API**, and routes to **synthetic fixture backends** by default. It does **not** yet route to Claude/OpenAI/Ollama; fixtures are safe placeholders until you supply model credentials and backend details.

## Structure

- `kubernetes/apps/ai/jev-routing/base/profile.json`: task taxonomy + thresholds.
- `jev-adapter.yaml`: Go adapter (CPU only), SecretRef, Service.
- `agentgateway.yaml`: isolated Gateway + pre-routing Envoy ExtProc policy.
- `backends-fixture.yaml`: two zero-inference OpenAI-style fixtures.
- `routes-fixture.yaml`: headers-to-backend `HTTPRoute`.
- `kustomization.yaml`: profile ConfigMap with hash-based rollout and container image replacement.
- `scripts/build-pinned-adapter.sh`: build upstream Go source at pinned commit.

## Requirements / important constraints

- Talos cluster with `ai` namespace, kubectl, GitOps/Kustomize, a reachable image registry, Gateway API support.
- **agentgateway OSS controller** v1.5.0 and its matching CRDs. This is **distinct from KGateway**; do not assume existing KGateway policies support the `agentgateway.dev` API resources. Check Gateway API v1.6.1 experimental CRDs compatibility before installing them (the original demo expects these).
- A TypeSafe Jev API key. Its request prompts leave your homelab for classification. Do not route confidential repo content before approval.
- Upstream demo supports only one string user message, `model: auto`, no tools, no streaming, no attachments, body max 32 KiB. Unsupported requests are rejected. No retries on classifier timeouts; `FailClosed` blocks requests on errors.
- Original authors have **not validated real Jev API integration or cluster deployment** for this exact version. Treat as a lab until validated.

## Build and publish

```bash
export IMAGE=ghcr.io/YOUR_ORG/jev-routing-adapter:part5
bash scripts/build-pinned-adapter.sh
PUSH=true bash scripts/build-pinned-adapter.sh
```

Set `newName` and `newTag` in `kubernetes/apps/ai/jev-routing/base/kustomization.yaml` to the pushed image.

## Install control plane (explicit opt-in)

If your current cluster already has agentgateway OSS v1.5.0 and compatible experimental Gateway API CRDs, skip. Otherwise, **review existing installed Gateway API CRDs and KGateway controller compatibility first**. The reference installer uses Gateway API v1.6.1 **experimental** CRDs. Installation scripts in this package intentionally don't overwrite Gateway API CRDs automatically:

```bash
export KUBE_CONTEXT=YOUR_TALOS_CONTEXT
bash scripts/install-agentgateway-oss.sh
```

## Secret (example local command; prefer encrypted SOPS/KSOPS for GitOps)

```bash
kubectl --context "$KUBE_CONTEXT" create namespace ai --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply -f -
read -rsp 'TypeSafe API key: ' TYPESAFE_API_KEY; echo
kubectl --context "$KUBE_CONTEXT" -n ai create secret generic typesafe-jev \
  --from-literal=TYPESAFE_API_KEY="$TYPESAFE_API_KEY" \
  --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply -f -
unset TYPESAFE_API_KEY
```

For durable GitOps, replace this imperative Secret with an encrypted `Secret` managed by your existing SOPS workflow; never commit a plaintext key.

## Apply, validate and test

```bash
kubectl --context "$KUBE_CONTEXT" apply -k kubernetes/apps/ai/jev-routing/base
kubectl --context "$KUBE_CONTEXT" -n ai rollout status deployment/jev-extproc
kubectl --context "$KUBE_CONTEXT" -n ai get gateway jev-routing
kubectl --context "$KUBE_CONTEXT" -n ai get httproute jev-routes -o yaml
kubectl --context "$KUBE_CONTEXT" -n ai port-forward svc/jev-routing 18085:8080
# From another terminal:
bash scripts/test-routing.sh
```

Check the Gateway is Programmed, route Accepted/ResolvedRefs=True, policy attached and Jev API calls work **before** interpreting the result. Fixture responses only test routing, not model accuracy or savings.

## Before production

1. Replace fixture backend objects with validated `AgentgatewayBackend` credentials/config for your chosen real hosted providers or OpenAI-compatible on-cluster endpoints. Do not blindly reuse the demo's fake model names.
2. Set routing policy for your real tasks and risk/quality budgets; the demo routes *coding to coding fixture* and *all other tasks to general fixture*, not local-vs-premium economics.
3. Extend the adapter for multi-turn conversations, tools and streaming (the original upstream adapter explicitly rejects them).
4. Implement identity, rate limits, safe failure behavior, tracing, and model-spend metrics; hosted Jev request overhead must be included in total spend.
5. Integrate with your ArgoCD application or Helmfile only after the isolated smoke tests pass.

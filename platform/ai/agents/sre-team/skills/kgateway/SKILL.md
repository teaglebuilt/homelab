---
name: kgateway
description: >
  Gateway API and kgateway ingress routing for the homelab. Use for north-south
  traffic — how a request from outside reaches a Service: Gateway and HTTPRoute
  status, listener and hostname conflicts, backend resolution, cross-namespace
  ReferenceGrants, TLS listeners and kgateway policies. Not for pod-to-pod
  connectivity. Carries the three GatewayClasses, the condition-reading order,
  and the quiet failures.
---

# Gateway API and kgateway for the homelab

You own north-south routing: how a request from outside reaches a Service.

## Three GatewayClasses

This estate runs three controllers at once. Identifying which one owns the
Gateway in question is **always the first step** — their failure modes and their
CRDs do not overlap.

| Class | Controller | Serves |
| --- | --- | --- |
| `kgateway` | `kgateway.dev/kgateway` | app ingress, Envoy data plane |
| `cilium` | `io.cilium/gateway-controller` | `homelab-internal-gateway`, LAN |
| `agentgateway` | `agentgateway.dev/agentgateway` | `ai-gateway`, MCP and LLM traffic |

A Gateway's `spec.gatewayClassName` tells you the owner. A route attached to a
Gateway whose class you are not reasoning about will not behave as you expect.

kgateway is deployed through the `homelab-gateway` wrapper chart, which vendors
the kgateway CRDs and kgateway itself as subchart dependencies and layers
Gateway, HTTPRoute and Certificate templates on top. Durable changes belong in
that chart — `kubernetes/charts/homelab-gateway/` — not in a live patch.

## Status is the diagnosis

Gateway API reports everything through conditions. Reading them in order
localises a fault faster than any log.

**On a Gateway:**

- `Accepted` — the controller claimed it.
- `Programmed` — the data plane is actually serving.
- Accepted without Programmed is a controller or infrastructure problem, not a
  config problem.
- Per-**listener** conditions carry their own `ResolvedRefs`. A TLS secret that
  does not exist, or sits in another namespace, shows up there — not on the
  Gateway as a whole. This is why a Gateway can look healthy while one listener
  is dead.
- `attachedRoutes` per listener tells you whether any route bound at all.

**On an HTTPRoute,** `parents[]` has one entry per Gateway it tried to attach to:

| Condition | Reason | Meaning |
| --- | --- | --- |
| `Accepted=False` | `NotAllowedByListeners` | the Gateway's `allowedRoutes` rejected it — usually a namespace selector |
| `Accepted=False` | `NoMatchingParent` | the `parentRef` names a Gateway, section or port that does not exist |
| `ResolvedRefs=False` | `BackendNotFound` | the Service is missing or misnamed |
| `ResolvedRefs=False` | `RefNotPermitted` | a cross-namespace backend needs a ReferenceGrant |

A route that is `Accepted` **and** `ResolvedRefs` but still not serving is a
data plane question, not a config question — go to the Envoy pod's logs.

## The quiet failures

These produce no error anywhere, which is why they survive long investigations:

1. **Hostname intersection.** A route whose hostnames do not intersect the
   listener's hostname attaches cleanly and matches nothing. Check it
   explicitly and early.
2. **ReferenceGrant direction.** The grant lives in the **target** namespace and
   names the **source** namespace and kind. Getting it backwards is the common
   mistake, and the symptom is `RefNotPermitted` on an object that looks correct.
3. **Rule ordering.** Gateway API matches most-specific-first, not
   first-listed. A broad `PathPrefix: /` rule does not shadow a more specific
   one, but a wrongly-typed match can.

## kgateway policy CRDs

All in the `gateway.kgateway.dev` group, all `v1alpha1`:

`TrafficPolicy`, `BackendConfigPolicy`, `HTTPListenerPolicy`, `ListenerPolicy`,
`GatewayParameters`, `Backend`, `DirectResponse`, `GatewayExtension`.

Query them by full resource name. When you patch one pass `patch_type: merge` —
these are CRDs and a strategic merge patch will fail.

## Boundaries

This is not east-west traffic. Pod-to-pod connectivity, identities and policy
drops belong to the Cilium specialists. Say so rather than guessing.

## Safety

Read `k8s_get_resource_yaml` on the Gateway and the HTTPRoute and compare their
status blocks before theorising. Most reports resolve there.

Confirm with the operator before mutating a Gateway, route or policy, and note
that the durable fix usually belongs in `homelab-gateway`.

## Reporting

Name the GatewayClass, the exact condition that is False with its reason, and
the object it is on. Give the fix as YAML and say where in the repo it belongs.

# Agent Debugging

How to find out what a kagent agent actually did, and whether a failure was
egress or something else. Written from the 2026-11-18 `medday-developer`
investigation; the worked example at the bottom is that run.

## Where the evidence lives

| Signal | Where | Cluster |
| --- | --- | --- |
| Allowed/denied HTTP egress, per actor | `deploy/atenet-egress` in `ate-system` | mlops |
| Sandbox DNS policy decisions, actor lifecycle | the worker pod in `ai` | mlops |
| Agent runtime errors (MCP connect, etc.) | same worker pod (agent stdout is relayed) | mlops |
| **Tool calls and their output** | **Tempo `svc/tempo:3200`** | **application** |
| Agent log lines | Loki `svc/loki-gateway` — content elided, see below | application |

Four traps:

- `loki-gateway-mesh` in **mlops** has no endpoints. It is a ClusterMesh global
  service; port-forward `svc/loki-gateway` in the **application** cluster.
- `svc/kagent-controller:8083` is gRPC. Plain HTTP GETs return `200` with an
  empty body for every path, including nonsense ones. That is not a REST API.
- The egress gateway only logs what reaches it. A host with no grant fails at
  the sandbox resolver and never appears. Absence of a log line is not
  absence of an attempt.
- A backgrounded `kubectl port-forward` dies as soon as its stdout pipe closes,
  so `port-forward … | head -3 &` gives you one request and then connection
  refused. Redirect to a file, and run the forward and the `curl` in the same
  shell invocation.

## 1. Identify the agent and its actor

The session uuid a user quotes ("the agent is `01a1f04c-…`") is the
`gen_ai.conversation.id`. The actor name is `session-<that uuid>`.

```bash
kubectl --context=mlops get agents -A
kubectl --context=mlops get agent <name> -n ai -o yaml | grep -A5 egressPolicyRefs
kubectl --context=mlops get egresspolicy <name> -n ai -o jsonpath='{.spec}' | python3 -m json.tool
kubectl --context=mlops get harness <harnessRef> -n ai -o yaml
kubectl --context=mlops get agenttemplate <name> -n ai -o yaml
```

`EgressPoliciesApplied: True` on the Agent means the grants were admitted, not
that any particular host is reachable.

## 2. Egress gateway: what was allowed, what was denied

Summarize every request the actor made, by host and status. This is the fastest
way to rule egress in or out.

```bash
ACTOR=session-01a1f04c-bb7a-7e07-b2c2-b390b754b1fc

kubectl --context=mlops logs -n ate-system deploy/atenet-egress --tail=200000 \
 | grep "ate.actor.name=$ACTOR" \
 | grep -o "http.host=[^ ]* .*http.status=[0-9]*" \
 | sed -E 's/.*http\.host=([^ ]*).*http\.status=([0-9]*).*/\2 \1/' \
 | sort | uniq -c | sort -rn
```

To watch a run live, capture to a file instead of streaming into the terminal:

```bash
timeout 120 kubectl --context=mlops logs -n ate-system deploy/atenet-egress --since=2m -f \
 | grep -E "$ACTOR|denied|blocked|403|RBAC|no healthy|upstream connect error|NXDomain|no such host" \
 > egress-live.log
```

Reading it:

- A **gateway denial has no paired `debug upstream request` line.**
- An **upstream status** (403, 502) means the request was allowed and the
  *server* refused it. Different problem — see `reference_grafana_mcp_portless_host`.
- `NXDomain` lines for `*.svc.svc.cluster.local` are the gateway's own search-domain
  walk. Harmless noise, not a denial.

## 3. Worker pod: sandbox DNS policy and actor lifecycle

Find the worker pod by the `worker_pod_uid` in the atelet log, or just list the pool.

```bash
kubectl --context=mlops get workerpools -A

kubectl --context=mlops get pods -A -o json | python3 -c "
import json,sys
for p in json.load(sys.stdin)['items']:
    if p['metadata']['uid']=='<worker_pod_uid>':
        print(p['metadata']['namespace'], p['metadata']['name'])
"

POD=kagent-default-<hash>
kubectl --context=mlops logs $POD -n ai --since=60m > worker.log

grep -ohE '"msg":"[^"]*(DNS|egress|policy|block)[^"]*"' worker.log | sort | uniq -c | sort -rn
grep "<actor.uid>" worker.log | grep -iE "dns|block|no such host|reject"
```

Two messages matter:

- `Actor has no egress policy; blocking all DNS queries` — no `EgressPolicy`
  attached at all. Every hostname NXDOMAINs on `169.254.17.1`, which reads as
  `no such host` and looks like a typo. See `reference_kagent_substrate_egress_dns`.
- `Actor has an egress policy` — a policy is compiled. **Per-query denials are
  not logged at any level**, so you cannot learn *which* host was blocked here.
  Go to Tempo.

Also check the atelet for restore/checkpoint failures, which look like app errors:

```bash
kubectl --context=mlops logs -n ate-system ds/atelet --all-containers --tail=400 \
 | grep -iE "Restore|Checkpoint|wakeup probe"
```

## 4. Tempo: the tool calls and their output

This is the decisive source. The harness sets

```yaml
OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT: SPAN_ONLY
```

so prompts, tool arguments and tool results are on **span attributes** only.
Loki shows `{"content":"<elided>"}` for every line.

```bash
kubectl --context=application port-forward -n observability svc/tempo 13200:3200 &
sleep 5

curl -sG localhost:13200/api/search \
  --data-urlencode 'q={resource.service.name="medday-developer"}' \
  --data-urlencode "start=$(( $(date +%s) - 3600 ))" \
  --data-urlencode "end=$(date +%s)" --data-urlencode "limit=20" \
| python3 -c "
import json,sys,datetime
for t in sorted(json.load(sys.stdin).get('traces',[]), key=lambda x:-int(x['startTimeUnixNano'])):
    st=int(t['startTimeUnixNano'])//10**9
    print(datetime.datetime.fromtimestamp(st).strftime('%H:%M:%S'),
          t['traceID'], t.get('rootTraceName'), t.get('durationMs'))
"

curl -s localhost:13200/api/traces/<traceID> -o trace.json
```

List the span names to see the shape of the run, then dump the tool spans:

```bash
python3 - <<'EOF'
import json
d=json.load(open('trace.json'))
def walk(o):
    if isinstance(o,dict):
        yield o
        for v in o.values(): yield from walk(v)
    elif isinstance(o,list):
        for v in o: yield from walk(v)

for s in walk(d):
    if str(s.get('name','')).startswith('execute_tool') and 'attributes' in s:
        print('='*70)
        print(s['name'], s.get('startTimeUnixNano'))
        for a in s['attributes']:
            if a['key'] in ('gcp.vertex.agent.tool_call_args',
                            'gcp.vertex.agent.tool_response',
                            'gen_ai.conversation.id'):
                print(' ', a['key'], '=', a['value'].get('stringValue','')[:3000])
EOF
```

Attributes worth knowing:

- `gcp.vertex.agent.tool_call_args` — the exact command string.
- `gcp.vertex.agent.tool_response` — stdout/stderr or the error. **Truncated on
  long output**, so a tail that looks like a clean finish may just be cut off.
  Judge success by the absence of `Error executing command`, not by the tail.
- `gen_ai.conversation.id` — the session uuid.
- Span names: `invoke_agent <name>` is the root, `execute_tool bash` and
  `execute_tool load_skill` are the interesting leaves, `generate_content
  <model>` is the LLM call.

## 5. Loki, for the record

Useful for infrastructure components, not for agent reasoning or tool output.

```bash
kubectl --context=application port-forward -n observability svc/loki-gateway 13101:80 &
sleep 5
curl -s localhost:13101/loki/api/v1/labels
curl -s localhost:13101/loki/api/v1/label/service_name/values
```

Agents appear as their own `service_name` (e.g. `medday-developer`). Query with
`{service_name="<agent>"}` — every content field will be `<elided>` while
`SPAN_ONLY` is set.

## Correlating the window

Once Tempo gives you the span start time of the failing tool call, go back to
the egress capture and look at that exact window. If the only traffic is
kagent control-plane, OTel and LLM calls, the sandbox process made no outbound
requests and egress is not your problem.

```bash
awk '$1>="2026-11-18T20:16:49"' egress-live.log | grep -oE "http.host=[^ ]+|http.status=[0-9]+"
```

## Worked example: `pnpm check-types` "egress block" that was not one

Agent `medday-developer`, session `01a1f04c-bb7a-7e07-b2c2-b390b754b1fc`,
trace `7c122f7d09916666a3815038aa287d13`.

Egress summary for the actor — every request 200, zero denials:

```
 78 200 registry.npmjs.org
  6 200 otel-agent-collector.observability.svc.cluster.local
  4 200 kagent-controller.ai.svc.cluster.local
  2 200 api.githubcopilot.com
  1 200 vllm-selfhosted.ai / mcp.context7.com / kb-mcp-read.ai /
        firecrawl-mcp.automation / api.openai.com
```

The `execute_tool bash` spans told the real story:

```
git clone … nextgensolutions-llc/medday   -> 563 files, ok
pnpm install --frozen-lockfile            -> 667 packages, all postinstalls Done
pnpm check-types                          -> Error executing command: command timed out after 30s
```

The `bash` tool's own description states the limit:

```
Timeouts:
- python scripts: 60s
- other commands: 30s
```

Confirmed not egress: during the check-types window (20:16:49–20:17:19 UTC) the
sandbox made no outbound requests at all. The `no such host` MCP errors in the
worker log belonged to a **different, earlier actor** (`bc12e80b`, Nov 17) that
had no policy; this actor logged `Actor has an egress policy` and its startup
MCP errors were `EOF` / `server closed idle connection` — cold-start races.

See `reference_kagent_bash_tool_30s_timeout` for the limit and the workarounds.

## Checklist

1. Resolve agent -> actor name -> `EgressPolicy` grants.
2. Aggregate the egress log by host and status. Any non-200? Any host missing
   that you expected to see?
3. Worker log: does the actor have a policy at all?
4. Tempo: read `execute_tool` spans for the actual command and the actual error.
5. Correlate the failing span's window against the egress capture before
   blaming the network.

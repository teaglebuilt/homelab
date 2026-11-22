import json
import os
import ssl
import time
import urllib.request

API = "https://kubernetes.default.svc"
NS = os.environ.get("NAMESPACE", "ai")
OTLP = os.environ.get(
    "OTLP_ENDPOINT",
    "http://otel-agent-collector.observability.svc.cluster.local:4318/v1/metrics",
)
SA = "/var/run/secrets/kubernetes.io/serviceaccount"
CRD = "/apis/api.kagent.dev/v1alpha3/namespaces/%s/%s"


def k8s(resource):
    with open(f"{SA}/token") as f:
        token = f.read().strip()
    ctx = ssl.create_default_context(cafile=f"{SA}/ca.crt")
    req = urllib.request.Request(
        API + CRD % (NS, resource), headers={"Authorization": f"Bearer {token}"}
    )
    with urllib.request.urlopen(req, context=ctx, timeout=15) as r:
        return json.load(r)["items"]


def attr(key, value):
    return {"key": key, "value": {"stringValue": value or ""}}


configs = {
    m["metadata"]["name"]: m["metadata"].get("labels", {}) for m in k8s("modelconfigs")
}
templates = {t["metadata"]["name"]: t for t in k8s("agenttemplates")}

points = []
now = str(time.time_ns())
for agent in k8s("agents"):
    name = agent["metadata"]["name"]
    labels = agent["metadata"].get("labels", {})
    tmpl = templates.get(agent.get("spec", {}).get("template", {}).get("ref", {}).get("name"), {})
    tmpl_labels = tmpl.get("metadata", {}).get("labels", {})
    model_config = tmpl.get("spec", {}).get("modelConfig", {}).get("name", "")
    mc = configs.get(model_config, {})
    owner = labels.get("ai.homelab/cost-owner") or tmpl_labels.get("ai.homelab/cost-owner", "")
    points.append(
        {
            "attributes": [
                attr("agent", name),
                attr("cost_owner", owner),
                attr("model_config", model_config),
                attr("tier", mc.get("ai.homelab/tier")),
                attr("paid", mc.get("ai.homelab/paid")),
                attr("route", mc.get("ai.homelab/route")),
            ],
            "timeUnixNano": now,
            "asDouble": 1,
        }
    )

body = {
    "resourceMetrics": [
        {
            "resource": {"attributes": [attr("service.name", "ai-cost-audit")]},
            "scopeMetrics": [
                {
                    "metrics": [
                        {
                            "name": "ai_agent_info",
                            "description": "Agent to cost owner and model tier, from live kagent objects",
                            "gauge": {"dataPoints": points},
                        }
                    ]
                }
            ],
        }
    ]
}
req = urllib.request.Request(
    OTLP,
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=15) as r:
    print(f"pushed {len(points)} agents, status {r.status}")

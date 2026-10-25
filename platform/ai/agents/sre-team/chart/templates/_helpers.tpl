{{/* Labels applied to every resource in this chart. */}}
{{- define "sre-team.labels" -}}
app.kubernetes.io/part-of: homelab
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Shared preamble for every agent in the team. kagent's own template
delimiters are emitted literally; Helm must not evaluate them.
*/}}
{{- define "sre-team.preamble" -}}
{{ `{{include "builtin/safety-guardrails"}}` }}
{{ `{{include "builtin/tool-usage-best-practices"}}` }}
{{- end -}}

{{/* Estate facts every agent needs. Keep terse: the team runs on a local model. */}}
{{- define "sre-team.estate" -}}
# Estate
Two Talos clusters. `mlops` runs the GPU/agent stack and kagent itself.
`application` runs the observability hub: Prometheus, Grafana, Loki, Tempo.
You execute inside `mlops`, so cross-cluster reads go through Cilium
ClusterMesh global Services, not the application cluster's local names.

Prometheus (reachable): {{ .Values.endpoints.prometheus }}
Grafana datasource UIDs: prometheus={{ .Values.datasourceUids.prometheus }}, loki={{ .Values.datasourceUids.loki }}, tempo={{ .Values.datasourceUids.tempo }}
Loki and Tempo retain {{ .Values.retention }}. Never query a wider range.
{{- end -}}

{{/* promptTemplate block wiring the builtin prompts ConfigMap. */}}
{{- define "sre-team.promptTemplate" -}}
promptTemplate:
  dataSources:
    - name: {{ .Values.builtinPrompts }}
      alias: builtin
{{- end -}}

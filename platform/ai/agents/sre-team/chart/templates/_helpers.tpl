{{/* Labels applied to every resource in this chart. */}}
{{- define "sre-team.labels" -}}
app.kubernetes.io/part-of: homelab
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/* Builtin preamble, root only. kagent's delimiters are emitted literally. */}}
{{- define "sre-team.preamble" -}}
{{ `{{include "builtin/safety-guardrails"}}` }}
{{ `{{include "builtin/tool-usage-best-practices"}}` }}
{{ `{{include "builtin/skills-usage"}}` }}
{{- end -}}

{{/* Estate facts the root needs before it loads its skill. */}}
{{- define "sre-team.estate" -}}
# Estate
Two Talos clusters. You execute in `mlops` (GPU and agent stack). The
observability hub — Prometheus, Grafana, Loki, Tempo — runs in `application`
and is reached over Cilium ClusterMesh global Services.
Loki and Tempo retain {{ .Values.retention }}. Never ask for a wider range.
{{- end -}}

{{/* Specialist opening. Call with (dict "name" "<x>" "skill" "<y>"). */}}
{{- define "sre-team.subagent" -}}
You are the {{ .name }} specialist for `teaglebuilt/homelab`. You are a
subagent: one concrete question in, findings out. You do not delegate.

Load your `{{ .skill }}` skill first and follow it in full, not just its
description — it holds your method, query syntax and safety rules. If the skill
tool is unavailable, read `/skills/{{ .skill }}/SKILL.md`.
{{- end -}}

{{/* Plugin binding for one skill. Call with (dict "root" . "skill" "<name>"). */}}
{{- define "sre-team.plugin" -}}
plugins:
  - source:
      oci: {{ .root.Values.plugin.oci }}
    skills:
      - {{ .skill }}
{{- end -}}

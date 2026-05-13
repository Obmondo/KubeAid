{{/*
hetzner.clusterAutoscalerLabels

Renders a nodeGroup's `labels` map (an arbitrary key→value mapping)
as the comma-separated `key=value` string that cluster-autoscaler's
capacity.cluster-autoscaler.kubernetes.io/labels annotation expects.

Input: a nodeGroup object (a single entry from .Values.nodeGroups.*).
Output: e.g. `role=worker,zone=fsn1` — or empty string when the
nodeGroup has no labels.

Used in MachineDeployment.yaml to keep the annotation YAML readable
instead of inlining a multi-step range/append/join on one line.
*/}}
{{- define "hetzner.clusterAutoscalerLabels" -}}
{{- $labels := list -}}
{{- range $key, $value := .labels -}}
{{- $labels = append $labels (printf "%s=%s" $key $value) -}}
{{- end -}}
{{- join "," $labels -}}
{{- end -}}

{{/*
hetzner.clusterAutoscalerTaints

Renders a nodeGroup's `taints` list as the comma-separated
`key=value:effect` string that cluster-autoscaler's
capacity.cluster-autoscaler.kubernetes.io/taints annotation expects.

Input: a nodeGroup object whose `.taints` is a list of
  { key: string, value: string, effect: string }
Output: e.g. `dedicated=gpu:NoSchedule,workload=batch:PreferNoSchedule`
— or empty string when there are no taints.
*/}}
{{- define "hetzner.clusterAutoscalerTaints" -}}
{{- $taints := list -}}
{{- range $taint := .taints -}}
{{- $taints = append $taints (printf "%s=%s:%s" $taint.key $taint.value $taint.effect) -}}
{{- end -}}
{{- join "," $taints -}}
{{- end -}}

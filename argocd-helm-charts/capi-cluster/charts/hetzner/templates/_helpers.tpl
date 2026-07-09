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

{{/*
MachineTemplate name rotation
=============================

ClusterAPI decides whether a Machine is up to date by comparing the *name*
of the template it was cloned from against the name the owner currently
references — KubeadmControlPlane via `spec.machineTemplate.spec.infrastructureRef`
(`matchesTemplateClonedFrom`), MachineDeployment via
`spec.template.spec.infrastructureRef` (`MachineTemplateUpToDate`). Neither
ever compares the referenced template's *contents*.

A MachineTemplate spec is also immutable server-side. So editing one in place
is rejected, and deleting + recreating it under the same name changes nothing
that CAPI looks at: no rollout happens, and the new spec silently applies only
to machines created later. That leaves a cluster with mixed instance types and
no error anywhere.

Encoding a hash of the spec into the name fixes both: a changed `machineType`
(or `imageName`) yields a new name, the owner's infrastructureRef changes, and
CAPI performs a normal surge-then-remove rolling replacement. Changing only
`controlPlane.hcloud.replicas` leaves the spec — and therefore the name —
untouched, so the KubeadmControlPlane simply scales out and the new members
join etcd without replacing anything.

Gated on `global.machineTemplateRotation` because switching it on renames the
template even when the spec is unchanged, which rolls the control plane once.
Existing clusters opt in deliberately; when it is unset the legacy fixed names
are rendered and nothing moves.

The spec helpers below are the single source of truth for each template's
`spec.template.spec` — HCloudMachineTemplate.yaml renders them, and the name
helpers hash them. Keeping one definition is what guarantees the hash can never
drift from the spec it names.
*/}}

{{/*
hetzner.hcloudControlPlaneMachineTemplateSpec

Input: the root context.
Output: the `spec.template.spec` body of the control-plane HCloudMachineTemplate.
*/}}
{{- define "hetzner.hcloudControlPlaneMachineTemplateSpec" -}}
{{- $isPrivate := or (eq .Values.mode "hybrid") (eq .Values.network.type "private") -}}
imageName: {{ .Values.hcloud.imageName }}
placementGroupName: control-plane
type: {{ .Values.controlPlane.hcloud.machineType }}
publicNetwork:
  {{/* Nodes have no public IPv4/IPv6 when using a private network (hcloud
       with network.type=private) or when running in hybrid mode. */}}
  enableIPv4: {{ not $isPrivate }}
  enableIPv6: {{ not $isPrivate }}
{{- end -}}

{{/*
hetzner.hcloudControlPlaneMachineTemplateName

Input: the root context.
Output: `<clusterName>-control-plane`, suffixed with a short hash of the spec
when global.machineTemplateRotation is set.

Referenced by KubeadmControlPlane.yaml's infrastructureRef, so the two can
never disagree.
*/}}
{{- define "hetzner.hcloudControlPlaneMachineTemplateName" -}}
{{- $base := printf "%s-control-plane" .Values.global.clusterName -}}
{{- if .Values.global.machineTemplateRotation -}}
{{- $spec := include "hetzner.hcloudControlPlaneMachineTemplateSpec" . -}}
{{- printf "%s-%s" $base (trunc 8 (sha256sum $spec)) -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end -}}

{{/*
hetzner.hcloudNodeGroupMachineTemplateSpec

Input: a dict of { root: $, nodeGroup: <one entry of .Values.nodeGroups.hcloud> }.
Output: the `spec.template.spec` body of that node group's HCloudMachineTemplate.
*/}}
{{- define "hetzner.hcloudNodeGroupMachineTemplateSpec" -}}
{{- $root := .root -}}
{{- $nodeGroup := .nodeGroup -}}
{{- $isPrivate := or (eq $root.Values.mode "hybrid") (eq $root.Values.network.type "private") -}}
imageName: {{ $root.Values.hcloud.imageName }}
placementGroupName: {{ $nodeGroup.name }}
type: {{ $nodeGroup.machineType }}
publicNetwork:
  enableIPv4: {{ not $isPrivate }}
  enableIPv6: {{ not $isPrivate }}
{{- end -}}

{{/*
hetzner.hcloudNodeGroupMachineTemplateName

Input: a dict of { root: $, nodeGroup: <one entry of .Values.nodeGroups.hcloud> }.
Output: `<clusterName>-<nodeGroup.name>`, suffixed with a short hash of the spec
when global.machineTemplateRotation is set.

Referenced by MachineDeployment.yaml's infrastructureRef. Note the MachineDeployment's
own name and its bootstrap configRef (the KubeadmConfigTemplate) are deliberately
NOT rotated — only the infrastructure template is.
*/}}
{{- define "hetzner.hcloudNodeGroupMachineTemplateName" -}}
{{- $base := printf "%s-%s" .root.Values.global.clusterName .nodeGroup.name -}}
{{- if .root.Values.global.machineTemplateRotation -}}
{{- $spec := include "hetzner.hcloudNodeGroupMachineTemplateSpec" . -}}
{{- printf "%s-%s" $base (trunc 8 (sha256sum $spec)) -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end -}}

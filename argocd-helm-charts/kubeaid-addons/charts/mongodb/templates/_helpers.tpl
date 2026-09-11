{{/*
Normalize global.mongodb into a list of instance dicts, so every template in
this subchart can `range` over one shape regardless of whether the caller
configured a single instance (global.mongodb.enabled + fields inline) or
several independent replica sets (global.mongodb.instances, each a full
instance object with its own enabled flag) -- e.g. an app that needs a
separate MongoDBCommunity per microservice, the way kilroy-config's
booking-engine chart does today with its own hand-rolled `mongodbDatabases`
list. Each returned instance already has its `enabled` filter applied --
callers just range over the result.
*/}}
{{- define "kubeaid-addons.mongodb.instances" -}}
{{- $instances := list -}}
{{- if (((.Values.global).mongodb).enabled) -}}
{{- $instances = append $instances .Values.global.mongodb -}}
{{- end -}}
{{- range (((.Values.global).mongodb).instances) -}}
{{- if .enabled -}}
{{- $instances = append $instances . -}}
{{- end -}}
{{- end -}}
{{- $instances | toJson -}}
{{- end -}}

{{/*
The distinct ServiceAccount names actually in use across all enabled
instances, so the RBAC templates render one Role/RoleBinding/ServiceAccount
per name rather than one per instance -- several instances in a namespace
normally share a single ServiceAccount, and re-declaring the same object
once per instance would be redundant.

"mongodb-kubernetes-appdb" is always in the list once any instance is
enabled, even when every instance overrides serviceAccountName: the MCK
(mongodb-kubernetes) operator re-applies that exact name to the database
StatefulSet on every reconcile no matter what the MongoDBCommunity asks
for, so it has to exist in the namespace regardless. If it doesn't, the
operator's first StatefulSet update deletes the running pod and Kubernetes
rejects the replacement with "serviceaccount mongodb-kubernetes-appdb not
found" -- zero mongod pods, application down.
*/}}
{{- define "kubeaid-addons.mongodb.serviceAccountNames" -}}
{{- $instances := include "kubeaid-addons.mongodb.instances" . | fromJsonArray -}}
{{- $names := list -}}
{{- if $instances -}}
{{- $names = append $names "mongodb-kubernetes-appdb" -}}
{{- end -}}
{{- range $instances -}}
{{- $names = append $names (.serviceAccountName | default "mongodb-kubernetes-appdb") -}}
{{- end -}}
{{- $names | uniq | toJson -}}
{{- end -}}

{{/*
Logical-backup targets: every mongodb entry (single global.mongodb, or any
entry of global.mongodb.instances) whose own logicalbackup.enabled is true --
deliberately independent of that entry's own `enabled`, so a CronJob can back
up an EXISTING, externally-managed MongoDBCommunity that this chart isn't
provisioning at all.
*/}}
{{- define "kubeaid-addons.mongodb.backupTargets" -}}
{{- $targets := list -}}
{{- if (((.Values.global).mongodb).logicalbackup).enabled -}}
{{- $targets = append $targets .Values.global.mongodb -}}
{{- end -}}
{{- range (((.Values.global).mongodb).instances) -}}
{{- if (.logicalbackup).enabled -}}
{{- $targets = append $targets . -}}
{{- end -}}
{{- end -}}
{{- $targets | toJson -}}
{{- end -}}

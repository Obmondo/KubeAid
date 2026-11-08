{{/* vim: set filetype=mustache: */}}

{{/*
Additional annotations
*/}}
{{- define "core-mw.podAnnotations" -}}
{{- if .podAnnotations }}
{{ toYaml .podAnnotations }}
{{- end }}
{{- end }}

{{/*
Add namespace and release version as environment variables
*/}}
{{- define "core-mw.env-variables" -}}
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: HELM_RELEASE_NAME
  value: {{ .Context.Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "core-mw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ox-common.names.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "core-mw.spellcheckHost" -}}
{{- if .Values.overrides.spellcheckHost }}
{{- printf "%s-%s" .Release.Name .Values.overrides.spellcheckHost | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name "core-spellcheck" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Computes the OX_BLACKLISTED_PACKAGES value based on the given configuration. When a packages is deemed to be disabled
it is added to the list. A package is disabled, if:
  * It is listed under packages.status with a value of 'disabled':
  packages:
    status:
      - open-xchange-authentication-database: 'disabled'
  OR if it is disabled as part of a feature in features.status:
  features:
    status:
      - admin: 'disabled'
  This would disable all packages that are listed at features.definitions.admin, UNLESS they are enabled again in the
  packages section.

  See the values.yaml file for default values
*/}}
{{- define "core-mw.blacklistedPackages" -}}
{{/* We'll assemble a list of blacklisted packages */}}
{{- $packages := dict -}}
{{- $features := .features.definitions -}}
{{/* Iterate the feature status subtree and add disabled packages to the blacklist, removing enabled packages */}}
{{- range $feature, $status := .features.status -}}
{{- if (hasKey $features $feature) -}}
{{-   $featurePackages := get $features $feature -}}
{{-   range $package := $featurePackages -}}
{{-     if eq $status "enabled" -}}
{{-       $_ := unset $packages $package -}}
{{-     else if eq $status "disabled" -}}
{{-       $_ := set $packages $package true -}}
{{-     else -}}
{{-       printf "Value for feature.status.%s is '%s' but needs to be either 'disabled' or 'enabled'" $feature $status | fail -}}
{{-     end  -}}
{{-   end  -}}
{{- else -}}
{{- printf "There is no \"%s\" feature in the \"features.definitions\", but it's defined in \"features.status\". Please check your configuration!" $feature | fail -}}
{{- end -}}
{{- end -}}
{{/* Iterate the package.status subtree and remove enabled packages from the blacklist, adding disabled ones */}}
{{- range $package, $status := .packages.status -}}
{{-   if eq $status "enabled" -}}
{{-     $_ := unset $packages $package -}}
{{-   else if eq $status "disabled" -}}
{{-     $_ := set $packages $package true -}}
{{-   else -}}
{{-     printf "Value for package.status.%s is '%s' but needs to be either 'disabled' or 'enabled'" $package $status | fail -}}
{{-   end  -}}
{{- end -}}
{{/* render space separated list */}}
{{- keys $packages | uniq | sortAlpha | join " " -}}
{{- end -}}

{{- define "core-mw.whitelistedPackages" -}}
  {{ .packages.whitelist | uniq | sortAlpha | join " " }}
{{- end -}}

{{- define "core-mw.propertiesList" -}}
{{- range $key, $value := . -}}
{{ $key }}={{ $value }}{{ print "\n" }}
{{- end -}}
{{ print "\n" }}
{{- end -}}

{{/*
Returns the names of the self-managed Secrets behind one `existing*Secret` / `existing*Secrets` pair as a
YAML list: the single name first, followed by every entry of the list. Empty names and duplicates are dropped.

Usage:
{{- $names := include "core-mw.existingSecretNames" (dict "Single" .Values.existingMetaSecret "List" .Values.existingMetaSecrets) | fromYamlArray }}
*/}}
{{- define "core-mw.existingSecretNames" -}}
{{- $names := list -}}
{{- if .Single -}}
{{-   $names = append $names (toString .Single) -}}
{{- end -}}
{{- range $name := (default list .List) -}}
{{-   if and $name (not (has (toString $name) $names)) -}}
{{-     $names = append $names (toString $name) -}}
{{-   end -}}
{{- end -}}
{{- $names | toYaml -}}
{{- end -}}

{{/*
Reports whether an `existing*Secret` / `existing*Secrets` pair names at least one Secret. Renders a non-empty
string if it does and nothing otherwise, so it MUST be used as a condition. A volumeMount MUST be gated on this
rather than on the raw values: a list holding nothing but empty entries is truthy, but yields no volume.

Usage:
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingMetaSecret "List" .Values.existingMetaSecrets) }}
*/}}
{{- define "core-mw.hasExistingSecrets" -}}
{{- if include "core-mw.existingSecretNames" . | fromYamlArray -}}true{{- end -}}
{{- end -}}

{{- define "core-mw.secretPropertiesYAML" -}}
{{- range $filename, $contentMap := .secretPropertiesFiles -}}
    {{ $filename }}: {{ toYaml (default dict $contentMap) | nindent 2 }}
    {{ print "\n" }}
{{- end -}}
{{- if .secretProperties }}
{{- print "\n\n" -}}
    anywhere: {{ toYaml .secretProperties | nindent 2 }}
  {{ print "\n" }}
{{- end }}
{{- end -}}

{{- define "core-mw.secretUIPropertiesYAML" -}}
{{- range $filename, $contentMap := (default dict .secretUISettingsFiles) -}}
{{ $filename }}:
{{- range $key, $value := (default dict $contentMap) }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- if .secretUISettings }}
{{- print "\n\n" -}}
/opt/open-xchange/etc/settings/overrides.properties:
{{- range $key, $value := .secretUISettings }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "core-mw.secretContextSetsYAML" -}}
{{- range $name, $contextSet := (default dict .secretContextSets) -}}
{{ $name }}:
{{- range $key, $value := (default dict $contextSet) }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{ print "\n" }}
{{- end }}
{{- end -}}

{{- define "core-mw.env" -}}
- name: SERVER_NAME
  value: {{ .Values.serverName | default "server" }}
- name: RELEASE_NAMESPACE
  value: {{ .Context.Release.Namespace }}
- name: OX_LOG_TO_CONSOLE
  value: "true"
- name: OX_BLACKLISTED_PACKAGES
  value:  {{ include "core-mw.blacklistedPackages" .Values }}
{{- if .Values.packages.whitelist }}
- name: OX_WHITELISTED_PACKAGES
  value: {{ include "core-mw.whitelistedPackages" .Values }}
{{- end }}
- name: OX_APPSUITE_APPROOT
  value: {{ include "ox-common.appsuite.appRoot" . | quote }}
{{- if .Values.globalDBID }}
- name: GLOBAL_DB_ID
  value: {{ .Values.globalDBID | quote }}
{{- end }}
- name: DCS_SERVICENAME
  value: {{ include "ox-common.dcs.serviceName" .Context }}
- name: DC_SERVER_URL
  value: {{ include "ox-common.dc.serverURL" .Context }}
{{- if or (and .Values.documentConverterClient.cache.remoteCache .Values.documentConverterClient.cache.remoteCache.url) (kindIs "string" .Values.documentConverterClient.cache.remoteCache.url) }}
- name: CS_SERVER_URL
  value: {{ toString (.Values.documentConverterClient.cache.remoteCache.url | default "") | quote }}
{{- else if or (index .Values "core-cacheservice").enabled (index .Values.global "core-cacheservice").enabled }}
- name: CS_SERVER_URL
  value: {{ include "ox-common.cs.serverURL" .Context }}
{{- end }}
- name: IC_SERVER_URL
  value: {{ include "ox-common.ic.serverURL" .Context }}
- name: SPELLCHECK_SERVER_URL
  value: {{ include "ox-common.spellcheck.serverURL" .Context }}
{{- if .Values.extraEnv }}
{{ toYaml .Values.extraEnv }}
{{- end }}
{{- end -}}

{{- define "core-mw.envFrom" -}}
- secretRef:
    name: {{ .Context.Release.Name }}-common-env
- secretRef:
    name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "secret-envvars") }}
{{- range $name := include "core-mw.existingSecretNames" (dict "Single" .Values.existingEnvSecret "List" .Values.existingEnvSecrets) | fromYamlArray }}
- secretRef:
    name: {{ $name | quote }}
{{- end }}
{{- end -}}

{{- define "core-mw.volumeMounts" -}}
- name: logs-{{.TypeName}}
  mountPath: /var/log/open-xchange
- name: spool-{{.TypeName}}
  mountPath: /var/spool/open-xchange/
- name: etc-files-{{.TypeName}}
  mountPath: /opt/open-xchange/etc/logback.xml
  subPath: logback.xml
- name: properties-{{.TypeName}}
  mountPath: /injections/configuration/properties
- name: properties-overwrite-{{.TypeName}}
  mountPath: /injections/configuration/properties-overwrite
- name: properties-languages-{{.TypeName}}
  mountPath: /opt/open-xchange/etc/languages/appsuite/languages.properties
  subPath: languages.properties
- name: properties-redis-{{.TypeName}}
  mountPath: /injections/configuration/properties-redis
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingPropertiesSecret "List" .Values.existingPropertiesSecrets) }}
- name: existing-properties-{{.TypeName}}
  mountPath: /injections/configuration/existing-properties
{{- end }}
- name: ui-settings-{{.TypeName}}
  mountPath: /injections/configuration/ui-settings
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingUISettingsSecret "List" .Values.existingUISettingsSecrets) }}
- name: existing-ui-settings-{{.TypeName}}
  mountPath: /injections/configuration/existing-ui-settings
{{- end }}
- name: meta-{{.TypeName}}
  mountPath: /injections/etc/meta/meta
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingMetaSecret "List" .Values.existingMetaSecrets) }}
- name: existing-meta-{{.TypeName}}
  mountPath: /injections/etc/existing-meta/meta
{{- end }}
- name: etc-files-{{.TypeName}}
  mountPath: /injections/etc/etc
- name: etc-secrets-{{.TypeName}}
  mountPath: /injections/etc/secretEtc
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingETCFilesSecret "List" .Values.existingETCFilesSecrets) }}
- name: existing-etc-files-{{.TypeName}}
  mountPath: /injections/etc/existingEtc
{{- end }}
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingETCBinariesSecret "List" .Values.existingETCBinariesSecrets) }}
- name: existing-etc-binaries-{{.TypeName}}
  mountPath: /injections/etc/existingSecretEtc
{{- end }}
- name: yaml-files-{{.TypeName}}
  mountPath: /injections/etc/yaml
- name: yaml-secrets-{{.TypeName}}
  mountPath: /injections/etc/secretYaml
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingYAMLFilesSecret "List" .Values.existingYAMLFilesSecrets) }}
- name: existing-yaml-files-{{.TypeName}}
  mountPath: /injections/etc/existingSecretYaml
{{- end }}
{{- if .Values.existingASConfigSecret }}
- name: existing-as-config-{{.TypeName}}
  mountPath: /injections/etc/existing-as-config
{{- else }}
- name: as-config-{{.TypeName}}
  mountPath: /injections/etc/as-config
{{- end }}
- name: context-sets-{{.TypeName}}
  mountPath: /injections/etc/context-sets/contextSets
{{- if include "core-mw.hasExistingSecrets" (dict "Single" .Values.existingContextSetsSecret "List" .Values.existingContextSetsSecrets) }}
- name: existing-context-sets-{{.TypeName}}
  mountPath: /injections/etc/existing-context-sets/contextSets
{{- end }}
- name: start-hooks-{{.TypeName}}
  mountPath: /hooks/start/helm/
- name: before-apply-hooks-{{.TypeName}}
  mountPath: /hooks/beforeApply/helm/
- name: before-appsuite-start-hooks-{{.TypeName}}
  mountPath: /hooks/beforeAppsuiteStart/helm/
{{ if .Values.extraMounts }}
{{ toYaml .Values.extraMounts }}
{{ end }}
{{- end -}}

{{- define "core-mw.volumes" -}}
{{- $context := . -}}
{{- if (include "core-mw.provisioningGateway.onThisType" .) }}
- name: provisioning-gateway-config
  configMap:
    name: {{ include "ox-common.names.fullname" .Context }}-provisioning-gateway
- name: provisioning-gateway-descriptor
  emptyDir: {}
{{- if .Values.provisioningGateway.tls.enabled }}
- name: provisioning-gateway-tls
  secret:
    secretName: {{ required "provisioningGateway.tls.existingSecret is required when the gateway terminates TLS" .Values.provisioningGateway.tls.existingSecret }}
{{- end }}
{{- end }}
- name: shared-{{.TypeName}}
  emptyDir: {}
- name: disabled-bundles-{{.TypeName}}
  emptyDir: {}
- name: logs-{{.TypeName}}
  emptyDir: {}
- name: spool-{{.TypeName}}
  emptyDir: {}
- name: properties-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-secret") }}
      - secret:
      {{- if .Values.redis.existingSecret }}
          name: {{ .Values.redis.existingSecret }}
      {{- else }}
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-redis-secret") }}
      {{- end }}
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-configmap") }}
- name: properties-languages-{{.TypeName}}
  projected:
    sources:
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-languages-configmap") }}
- name: properties-overwrite-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-overwrite-secret") }}
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-overwrite-configmap") }}
- name: properties-redis-{{.TypeName}}
  projected:
    sources:
      - secret:
      {{- if .Values.redis.existingSecret }}
          name: {{ .Values.redis.existingSecret }}
      {{- else }}
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "properties-redis-secret") }}
      {{- end }}
{{- $existingPropertiesSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingPropertiesSecret "List" .Values.existingPropertiesSecrets) | fromYamlArray }}
{{- if $existingPropertiesSecretNames }}
- name: existing-properties-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingPropertiesSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
- name: ui-settings-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "ui-settings-secret") }}
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "ui-settings-configmap") }}
{{- $existingUISettingsSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingUISettingsSecret "List" .Values.existingUISettingsSecrets) | fromYamlArray }}
{{- if $existingUISettingsSecretNames }}
- name: existing-ui-settings-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingUISettingsSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
- name: meta-{{.TypeName}}
  projected:
    sources:
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "meta-configmap") }}
{{- $existingMetaSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingMetaSecret "List" .Values.existingMetaSecrets) | fromYamlArray }}
{{- if $existingMetaSecretNames }}
- name: existing-meta-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingMetaSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
- name: etc-files-{{.TypeName}}
  projected:
    sources:
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "etc-files-configmap") }}
      {{ range .Values.etcBinaries }}
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" $context "ResourceName" "etc-binaries-configmap") }}-{{ .name }}
      {{ end }}
- name: etc-secrets-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "etc-secrets-secret") }}
      {{ range .Values.secretETCBinaries }}
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" $context "ResourceName" "etc-binaries-secret") }}-{{ .name }}
      {{ end }}
{{- $existingETCFilesSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingETCFilesSecret "List" .Values.existingETCFilesSecrets) | fromYamlArray }}
{{- if $existingETCFilesSecretNames }}
- name: existing-etc-files-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingETCFilesSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
{{- $existingETCBinariesSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingETCBinariesSecret "List" .Values.existingETCBinariesSecrets) | fromYamlArray }}
{{- if $existingETCBinariesSecretNames }}
- name: existing-etc-binaries-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingETCBinariesSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
- name: yaml-files-{{.TypeName}}
  projected:
    sources:
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "yaml-files-configmap") }}
          items:
          {{ range $relativePath, $content := .Values.yamlFiles }}
            - key: {{ splitList "/" $relativePath | last }}
              path: {{ $relativePath }}
          {{ end }}
- name: yaml-secrets-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "yaml-secrets-secret") }}
          items:
          {{ range $relativePath, $content := .Values.secretYAMLFiles }}
            - key: {{ splitList "/" $relativePath | last }}
              path: {{ $relativePath }}
          {{ end }}
{{- $existingYAMLFilesSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingYAMLFilesSecret "List" .Values.existingYAMLFilesSecrets) | fromYamlArray }}
{{- if $existingYAMLFilesSecretNames }}
- name: existing-yaml-files-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingYAMLFilesSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
- name: context-sets-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "contextsets-secret") }}
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "contextsets-configmap") }}
{{- $existingContextSetsSecretNames := include "core-mw.existingSecretNames" (dict "Single" .Values.existingContextSetsSecret "List" .Values.existingContextSetsSecrets) | fromYamlArray }}
{{- if $existingContextSetsSecretNames }}
- name: existing-context-sets-{{.TypeName}}
  projected:
    sources:
    {{- range $name := $existingContextSetsSecretNames }}
      - secret:
          name: {{ $name | quote }}
    {{- end }}
{{- end }}
- name: as-config-{{.TypeName}}
  projected:
    sources:
      - configMap:
          name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "as-config-configmap") }}
{{- if .Values.existingASConfigSecret }}
- name: existing-as-config-{{.TypeName}}
  projected:
    sources:
      - secret:
          name: {{ .Values.existingASConfigSecret }}
{{- end }}
- name: start-hooks-{{.TypeName}}
  configMap:
    name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "hook-start-configmap") }}
- name: before-apply-hooks-{{.TypeName}}
  configMap:
    name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "hook-before-apply-configmap") }}
- name: before-appsuite-start-hooks-{{.TypeName}}
  configMap:
    name: {{ include "core-mw.resourceName" (dict "DeploymentContext" . "ResourceName" "hook-before-appsuite-start-configmap") }}
{{ if .Values.extraVolumes }}
{{ toYaml .Values.extraVolumes }}
{{ end }}
{{- end -}}

{{- define "core-mw.containers" -}}
{{- $gw := .Values.provisioningGateway -}}
{{- if (include "core-mw.provisioningGateway.onThisType" .) }}
- name: provisioning-gateway
  image: {{ printf "%s:%s" $gw.image.repository $gw.image.tag | quote }}
  imagePullPolicy: {{ $gw.image.pullPolicy }}
  args:
    - "-c"
    - "/etc/envoy/envoy.yaml"
  ports:
    - name: provisioning
      containerPort: {{ $gw.port }}
      protocol: TCP
  resources:
    {{- toYaml $gw.resources | nindent 4 }}
  volumeMounts:
    - name: provisioning-gateway-config
      mountPath: /etc/envoy
      readOnly: true
    - name: provisioning-gateway-descriptor
      mountPath: {{ $gw.descriptorMountPath }}
      readOnly: true
    {{- if $gw.tls.enabled }}
    - name: provisioning-gateway-tls
      mountPath: {{ $gw.tls.mountPath }}
      readOnly: true
    {{- end }}
{{- end }}
{{- if .Values.extraContainers }}
{{ toYaml .Values.extraContainers }}
{{- end }}
{{- end -}}

{{/*
Whether the provisioning gateway sidecar belongs on the node type currently being rendered.
It is switched on globally but only runs next to the role that serves the provisioning API.
*/}}
{{- define "core-mw.provisioningGateway.onThisType" -}}
{{- $gw := .Values.provisioningGateway -}}
{{- if ($gw).enabled -}}
{{-   $roleMap := (include "core-mw.roleMap" (dict "Roles" .Roles)) | fromYaml -}}
{{-   if (get $roleMap $gw.role) -}}
true
{{-   end -}}
{{- end -}}
{{- end -}}

{{- define "core-mw.extraInitContainers" -}}
{{- $gw := .Values.provisioningGateway -}}
{{- if (include "core-mw.provisioningGateway.onThisType" .) }}
- name: provisioning-gateway-descriptor
  # A sidecar cannot read the middleware container's filesystem, so the descriptor is copied out of
  # the very image that serves the API. That is what keeps the two from drifting apart.
  image: {{ include "ox-common.images.image" (dict "imageRoot" .Values.image "global" .Context "context" .Context) }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  securityContext: {{ toYaml .Values.securityContext | nindent 4 }}
  command:
    - "/bin/sh"
    - "-c"
    - "cp /opt/open-xchange/grpc/provisioning.pb {{ $gw.descriptorMountPath }}/provisioning.pb"
  volumeMounts:
    - name: provisioning-gateway-descriptor
      mountPath: {{ $gw.descriptorMountPath }}
{{- end }}
{{- if .Values.extraInitContainers }}
{{ toYaml .Values.extraInitContainers }}
{{- end }}
{{- end -}}

{{/*
Creates a map out of a list of role names, so one can easier check whether a certain type has a certain role
Usage:
{{- $roleMap := (include "core-mw.roleMap" (dict "Roles" [list-of-roles])) -}}
{{- if (get $roleMap "role-name) -}}
{{-   ... -}}
{{- end -}}
*/}}
{{- define "core-mw.roleMap" -}}
{{- $context := . -}}
{{- $roleMap := dict -}}
{{- range $role := $context.Roles -}}
{{-   $roleMap = set $roleMap $role true -}}
{{- end -}}
{{ toYaml $roleMap}}
{{- end -}}


{{/*
Computes effective values for a given type with given roles. Say, a type of nodes has three roles:

- http-api
- sync
- custom-role

And specifies configuration in all of these roles sections like this:

roles:
  http-api:
    values:
      properties:
        ...
      ... any other configuration keys ..
  sync:
    values:
      properties:
        ...
      ... any other configuration keys ..
  custom-role:
    values:
      properties:
        ...
      ... any other configuration keys ..

and also in the scaling section for the type:

scaling:
  nodes:
    groupware:
      replicas: 3
      roles:
        - http-api
        - sync
        - custom-role
      values:
        properties:
         ...
        resources:
          requests:
            cpu: 0.1
            memory: 1G
          limits:
            memory: 1G
        javaOpts:
          memory:
            maxHeapSize: 512M # Default: 8GB

then this method will compute the resulting values in this order:

* general values of the helm chart
* overridden by the role specific values in the order of the roles specified in the scaling section
* type specific values in the scaling section

The result can then be used as the regular .Values would normally be used, but allows configuration to be overridden for roles and types.

Usage:
$values := ( include "core-mw.computeValuesFor" (dict "Context" $globalContext "Roles" $typeConfig.roles "TypeName" $typeName "TypeConfig" $typeConfig) | fromYaml )
*/}}
{{- define "core-mw.computeValuesFor" -}}
{{- $context := . -}}
{{- $typeName := .TypeName -}}
{{- $values := $context.Context.Values | deepCopy -}}
{{- range $role := $context.Roles -}}
{{-   if (hasKey $context.Context.Values.roles $role ) -}}
{{-     if (hasKey (get $context.Context.Values.roles $role) "values") -}}
{{-       $values = (mergeOverwrite $values (deepCopy (get (get $context.Context.Values.roles $role) "values"))) -}}
{{-     end -}}
{{-   end -}}
{{- end -}}
{{- if (hasKey $context.TypeConfig "values" ) -}}
{{-   $values = (mergeOverwrite $values (deepCopy $context.TypeConfig.values)) -}}
{{- end -}}
{{- include "core-mw.generateRandomValues" (dict "Context" $context.Context "Values" $values "TypeName" $typeName) -}}
{{- end -}}

{{/*
Generates random alphanumeric strings for missing values and merges them with the provided values.

Usage:
{{- $values = (include "core-mw.generateRandomValues" (dict "Context" $context.Context "Values" $values)) | fromYaml -}}
*/}}
{{- define "core-mw.generateRandomValues" -}}
{{- $context := .Context -}}
{{- $values := .Values -}}
{{- $typeName := .TypeName -}}
{{- $secretEnvVars := (include "core-mw.getSecretEnvVars" (dict "Context" $context "Values" $values) | fromYaml) -}}
{{- if not $typeName -}}
{{-   if not $secretEnvVars.credstoragePasscrypt -}}
{{-     $secretEnvVars = set $secretEnvVars "credstoragePasscrypt" (randAlphaNum 32) -}}
{{-   end -}}
{{-   if not $secretEnvVars.masterAdmin -}}
{{-     $secretEnvVars = set $secretEnvVars "masterAdmin" (randAlphaNum 8) -}}
{{-   end -}}
{{-   if not $secretEnvVars.masterPassword -}}
{{-     $secretEnvVars = set $secretEnvVars "masterPassword" (randAlphaNum 32) -}}
{{-   end -}}
{{-   if not $secretEnvVars.basicAuthLogin -}}
{{-     $secretEnvVars = set $secretEnvVars "basicAuthLogin" (randAlphaNum 8) -}}
{{-   end -}}
{{-   if not $secretEnvVars.basicAuthPassword -}}
{{-     $secretEnvVars = set $secretEnvVars "basicAuthPassword" (randAlphaNum 32) -}}
{{-   end -}}
{{-   if not $secretEnvVars.jolokiaLogin -}}
{{-     $secretEnvVars = set $secretEnvVars "jolokiaLogin" (randAlphaNum 8) -}}
{{-   end -}}
{{-   if not $secretEnvVars.jolokiaPassword -}}
{{-     $secretEnvVars = set $secretEnvVars "jolokiaPassword" (randAlphaNum 8) -}}
{{-   end -}}
{{- end -}}
{{- mergeOverwrite $values $secretEnvVars | toYaml -}}
{{- end -}}

{{/*
Usage:
metadata:
  annotations:
    checksum/existingSecrets: {{ include "core-mw.existingSecretsChecksum" (dict "Context" $globalContext "Values" $values) | quote }} 
*/}}
{{- define "core-mw.existingSecretsChecksum" -}}
{{- $context := .Context -}}
{{- $values := .Values -}}
{{- $result := dict -}}
{{- if $values.existingPropertiesSecret -}}
{{-   $existingPropertiesSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingPropertiesSecret)) -}}
{{-   if $existingPropertiesSecret.data -}}
{{-     $_ := set $result "existingPropertiesSecret" $existingPropertiesSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingUISettingsSecret -}}
{{-   $existingUISettingsSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingUISettingsSecret)) -}}
{{-   if $existingUISettingsSecret.data -}}
{{-     $_ := set $result "existingUISettingsSecret" $existingUISettingsSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingMetaSecret -}}
{{-   $existingMetaSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingMetaSecret)) -}}
{{-   if $existingMetaSecret.data -}}
{{-     $_ := set $result "existingMetaSecret" $existingMetaSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingContextSetsSecret -}}
{{-   $existingContextSetsSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingContextSetsSecret)) -}}
{{-   if $existingContextSetsSecret.data -}}
{{-     $_ := set $result "existingContextSetsSecret" $existingContextSetsSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingASConfigSecret -}}
{{-   $existingASConfigSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingASConfigSecret)) -}}
{{-   if $existingASConfigSecret.data -}}
{{-     $_ := set $result "existingASConfigSecret" $existingASConfigSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingETCFilesSecret -}}
{{-   $existingETCFilesSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingETCFilesSecret)) -}}
{{-   if $existingETCFilesSecret.data -}}
{{-     $_ := set $result "existingETCFilesSecret" $existingETCFilesSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingETCBinariesSecret -}}
{{-   $existingETCBinariesSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingETCBinariesSecret)) -}}
{{-   if $existingETCBinariesSecret.data -}}
{{-     $_ := set $result "existingETCBinariesSecret" $existingETCBinariesSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingYAMLFilesSecret -}}
{{-   $existingYAMLFilesSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingYAMLFilesSecret)) -}}
{{-   if $existingYAMLFilesSecret.data -}}
{{-     $_ := set $result "existingYAMLFilesSecret" $existingYAMLFilesSecret.data -}}
{{-   end -}}
{{- end -}}
{{- if $values.existingEnvSecret -}}
{{-   $existingEnvSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.existingEnvSecret)) -}}
{{-   if $existingEnvSecret.data -}}
{{-     $_ := set $result "existingEnvSecret" $existingEnvSecret.data -}}
{{-   end -}}
{{- end -}}
{{- /* The list values: one entry per Secret, keyed by name, so adding or removing a Secret changes the hash too */ -}}
{{- range $listKey := list "existingPropertiesSecrets" "existingUISettingsSecrets" "existingMetaSecrets" "existingETCFilesSecrets" "existingETCBinariesSecrets" "existingYAMLFilesSecrets" "existingContextSetsSecrets" "existingEnvSecrets" -}}
{{-   $collected := dict -}}
{{-   range $name := (default list (get $values $listKey)) -}}
{{-     if $name -}}
{{-       $secret := (lookup "v1" "Secret" $context.Release.Namespace (toString $name)) -}}
{{-       if $secret.data -}}
{{-         $_ := set $collected (toString $name) $secret.data -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   if $collected -}}
{{-     $_ := set $result $listKey $collected -}}
{{-   end -}}
{{- end -}}
{{- if $values.redis.existingSecret -}}
{{-   $existingRedisSecret := (lookup "v1" "Secret" $context.Release.Namespace (printf "%s" $values.redis.existingSecret )) -}}
{{-   if $existingRedisSecret.data -}}
{{-     $_ := set $result "existingRedisSecret" $existingRedisSecret.data -}}
{{-   end -}}
{{- end -}}
{{ $result | toString | sha256sum | trunc 63 }}
{{- end -}}

{{/*
Retrieves values from existing secret environment variables and returns them as a dictionary, which can be merged into other values.

Usage:
{{- $secretEnvVars := (include "core-mw.getSecretEnvVars" (dict "Context" $context "Values" $values) | fromYaml) -}}
*/}}
{{- define "core-mw.getSecretEnvVars" -}}
{{- $context := .Context -}}
{{- $values := .Values -}}
{{- $typeName := .TypeName -}}
{{- $credstoragePasscrypt := $values.credstoragePasscrypt -}}
{{- $masterAdmin := $values.masterAdmin -}}
{{- $masterPassword := $values.masterPassword -}}
{{- $basicAuthLogin := $values.basicAuthLogin -}}
{{- $basicAuthPassword := $values.basicAuthPassword -}}
{{- $jolokiaLogin := $values.jolokiaLogin -}}
{{- $jolokiaPassword := $values.jolokiaPassword -}}
{{- $secret := "" -}}
{{- if $typeName -}}
{{-   $secret = (lookup "v1" "Secret" $context.Release.Namespace (printf "%s-%s-%s-secret-envvars" $context.Release.Namespace $context.Chart.Name $typeName)) -}}
{{- else -}}
{{-   $secret = (lookup "v1" "Secret" $context.Release.Namespace (printf "%s-%s-secret-envvars" $context.Release.Namespace $context.Chart.Name )) -}}
{{- end -}}
{{- if and (not $credstoragePasscrypt) ((($secret).data).CREDSTORAGE_PASSCRYPT) -}}
{{-   $credstoragePasscrypt = index $secret.data.CREDSTORAGE_PASSCRYPT | b64dec -}}
{{- end -}}
{{- if and (not $masterAdmin) ((($secret).data).MASTER_ADMIN_USER) -}}
{{-   $masterAdmin = index $secret.data.MASTER_ADMIN_USER | b64dec -}}
{{- end -}}
{{- if and (not $masterPassword) ((($secret).data).MASTER_ADMIN_PW) -}}
{{-   $masterPassword = index $secret.data.MASTER_ADMIN_PW | b64dec -}}
{{- end -}}
{{- if and (not $basicAuthLogin) ((($secret).data).OX_BASIC_AUTH_LOGIN) -}}
{{-   $basicAuthLogin = index $secret.data.OX_BASIC_AUTH_LOGIN | b64dec -}}
{{- end -}}
{{- if and (not $basicAuthPassword) ((($secret).data).OX_BASIC_AUTH_PASSWORD) -}}
{{-   $basicAuthPassword = index $secret.data.OX_BASIC_AUTH_PASSWORD | b64dec -}}
{{- end -}}
{{- if and (not $jolokiaLogin) ((($secret).data).JOLOKIA_LOGIN) -}}
{{-   $jolokiaLogin = index $secret.data.JOLOKIA_LOGIN | b64dec -}}
{{- end -}}
{{- if and (not $jolokiaPassword) ((($secret).data).JOLOKIA_PASSWORD) -}}
{{-   $jolokiaPassword = index $secret.data.JOLOKIA_PASSWORD | b64dec -}}
{{- end -}}
{{ dict "credstoragePasscrypt" $credstoragePasscrypt "masterAdmin" $masterAdmin "masterPassword" $masterPassword "basicAuthLogin" $basicAuthLogin "basicAuthPassword" $basicAuthPassword "jolokiaLogin" $jolokiaLogin "jolokiaPassword" $jolokiaPassword | toYaml }}
{{- end -}}

{{/*
Usage:
metadata:
  annotations:
    checksum/allConfig: {{- ((include "core-mw.configChecksum" (dict "TypedResources" $typedResource "TypeName" $typeName "Context" $globalContext ) -}})) -}}

*/}}
{{- define "core-mw.configChecksum" -}}
{{- $globalContext := .Context -}}
{{- $typedResources := .TypedResources -}}
{{- $typeName := .TypeName -}}
{{- $configAsString := "" -}}
{{- range $resourceName := keys $typedResources | sortAlpha -}}
{{-    $resourceSpec := get $typedResources $resourceName -}}
{{-    $typedResourceSpec := get $resourceSpec.types $typeName -}}
{{-    if (not $typedResourceSpec.isDefault) -}}
{{-       $configAsString = printf "%s\n---\n%s" $configAsString (include $resourceSpec.template (dict "Values" $typedResourceSpec.values "Context" $globalContext "TypeName" $typeName "ResourceName" $typedResourceSpec.name )) -}}
{{-    else -}}
{{-       $configAsString = printf "%s\n---\n%s" $configAsString (include $resourceSpec.template (dict "Values" $resourceSpec.values "Context" $globalContext "ResourceName" $resourceSpec.name)) -}}
{{-    end -}}
{{- end -}}
{{ $configAsString | sha256sum | trunc 63 }}
{{- end -}}

{{/*

This function creates a data structure that, for every configured "type" of middleware pods gives us the effective values and the names of type specific resources:

as-config-configmap:
  needsDefault: true # Whether the default resource is used by any type
  name: "RELEASE-NAME-as-config-configmap" # The general name
  template: "core-mw.typeSpecific.as-config-configmap.template" # The template used to render this resource
  values: {} # the global values
  types:
    TYPE1:
      isDefault: false # Whether TYPE1 uses an as-config-configmap with overwritten configuration
      values: {} # The effective values for TYPE1
      name: "RELEASE-NAME-TYPE1-as-config-configmap" # The kubernetes resource name for this resource wrt to TYPE1. Either general or type specific
    TYPE2:
      isDefault: true # Whether TYPE2 uses an as-config-configmap with overwritten configuration
      values: {} # The effective values for TYPE2
      name: "RELEASE-NAME-as-config-configmap" # The kubernetes resource name for this resource wrt to TYPE2. Either general or type specific
configmap:
  needsDefault: true # Whether the default resource is used by any type
  name: "RELEASE-NAME-configmap" # The general name
  template: "core-mw.typeSpecific.configmap.template" # The template used to render this resource
  values: {} # the global values
  types:
    TYPE1:
      isDefault: false # Whether TYPE1 uses an configmap with overwritten configuration
      values: {} # The effective values for TYPE1
      name: "RELEASE-NAME-TYPE1-configmap" # The kubernetes resource name for this resource wrt to TYPE1. Either general or type specific
    TYPE2:
      isDefault: true # Whether TYPE2 uses an configmap with overwritten configuration
      values: {} # The effective values for TYPE2
      name: "RELEASE-NAME-configmap" # The kubernetes resource name for this resource wrt to TYPE2. Either general or type specific

With one entry for each resource listed in typeSpecific/_typedResource.tpl. This datastructure is then used to

a) render all typed resources in type-scoped-resources.yaml
b) Find out the names of the referenced kubernetes objects in env, envFrom and volumes. (See this files "core-mw.volumes" but also deployment.yaml )
c) Compute the checksum annotation on the container

To understand more about the role/type system of middleware nodes, read on:

## Types and Roles
Depending on how a middleware cluster is set up any of the middleware pods may fulfill different roles. In bigger clusters, for example, it may be desirable
to have certain pods handle http-api traffic or other pods handle the sync protocols. In smaller clusters however, it might be useful to consolidate these tasks into single pods.
The way we handle that in this chart is by using "roles" and "types"

In the scaling section of the configuration you can specify which types there are and how many you want of each. Let's look at an example:

core-mw:
  scaling:
    nodes:
      groupware:
        replicas: 3
        roles:
          - http-api
          - sync
          - businessmobility
      admin:
        replicas: 1
        roles:
          - admin

This gives us four pods, one reserved for provisioning (admin) and three for the rest of the functions. What does it mean to be reserved for a task? The helm chart sets up services for the roles and puts every pod that is supposed to serve that role into one of those services:

Role: **admin** Service: **RELEASE-NAME-core-mw-admin**

Role: **http-api** Service: **RELEASE-NAME-core-mw-http-api**

Role: **sync** Service: **RELEASE-NAME-core-mw-sync**

Role: **businessmobility** Service: **RELEASE-NAME-core-mw-businessmobility**

So incoming traffic routing can be set up accordingly. DAV goes to the SERVICE-NAME-core-mw-sync.appsuite.svc.cluster.local, EAS/ActiveSync to SERVICE-NAME-core-mw-businessmobility.appsuite.svc.cluster.local, HTTP-API traffic to appsuite-core-mw-http-api.appsuite.svc.cluster.local, internal SOAP calls via different Gateway on a different Port go to appsuite-core-mw-admin.appsuite.svc.cluster.local. We can also slice the cake differently, with, say specialised pods for all tasks:

scaling:
  nodes:
    http-api:
      replicas: 4
      roles:
        - http-api
    sync:
      replicas: 2
      roles:
        - sync
    admin:
      replicas: 1
      roles:
        - admin
    businessmobility:
      replicas: 2
      roles:
        - businessmobility

This gives us a cluster of 4 HTTP-API pods, 2 Sync pods, 2 businessmobility pods and 1 provisioning pod. Routing is still the same as above, since the pods will be added to the services matching the roles they have. If we don't want a separate sync cluster, we can consolidate them back into the http-api nodes:

scaling:
  nodes:
    http-api-and-sync:
      replicas: 4
      roles:
        - http-api
        - sync
    admin:
      replicas: 1
      roles:
        - admin
    businessmobility:
      replicas: 2
      roles:
        - businessmobility

etc ... Both roles and types can overwrite the general configuration of the middleware:

resources:
  limits:
    cpu: 2000m
    memory: 4G
  requests:
    cpu: 1000m
    memory: 4G

roles:
  sync:
    values:
      properties:
        com.openexchange.caldav.enabled: true

scaling:
  nodes:
    groupware:
      replicas: 3
      roles:
        - http-api
        - sync
      values:
        resources:
          resources:
            limits:
              memory: 8G
            requests:
              memory: 8G
    admin:
      replicas: 1
      roles:
        - admin

This would e.g. set different RAM limits and requests for the "groupware" nodes, while the "admin" node uses the default configuration. It also specifies a property
that is only going to be applied to pods of a type with the "sync" role.

## Custom Roles

An operator can also add custom roles. For example, one could separate our gdpr-worker pods and create a role for that, and, consequently, a type using that role:

core-mw:
  roles:
    gdpr-worker:
      services:
      - ports:
        - port: 80
          targetPort: http
          protocol: TCP
          name: http

scaling:
  nodes:
    gdpr-worker:
      replicas: 3
      roles:
        - gdpr-worker


This will also create a service called RELEASE-NAME-core-mw-TYPE (in thise case RELEASE-NAME-core-mw-gdpr-worker) that groups all the pods of that role

## Type Specific Kubernetes Resources

To make all of this work, we will have two versions of any type specific resource. Take, for example, the "properties-configmap" ConfigMap. If a type (or one of its roles) overrides anything
in properties or propertiesFiles, the Pod must use a custom version of the configmap specific to the type. If it doesn't, then it can use the default configmap. Take a look
at typeSpecific/properties-configmap.tpl. It defines two template functions "core-mw.typeSpecific.properties-configmap.options", which tells this routine here how to
determine if anything relevant to the actual kubernetes resource template has been overridden and "core-mw.typeSpecific.properties-configmap.template" with the actual
ConfigMap definition. That template gets passed "Values" with either the general or overridden values and a "ResourceName with either the general or type specific name.
This is, basically, the Strategy Pattern at work.

The name of the effective kubernetes resource name for a type can be retrieved using the core-mw.resourceName template:

{{ include "core-mw.resourceName" (dict "DeploymentContext" (dict "TypedResources" $typedResources "TypeName" "http-api") "ResourceName" "properties-configmap") }}

With $typedResources being the datastructure generated by this template.

## Adding a new typeSpecific resource

If you need to add a new typeSpecific resource, you need to

a) Create a RESOURCE-NAME.tpl file in the typeSpecific subdirectory.
b) Add RESOURCE-NAME to the list in typeSpecific/_typedResource.tpl
c) Define an options template. Take care to list all keys from the values used as "usedKeys"!
d) Define implementation templates

{{- define "core-mw.typSpecific.RESOURCE-NAME.options "-}}
...
{{- end -}}

{{- define "core-mw.typSpecific.RESOURCE-NAME.template "-}}
...
{{- end -}}

The Options template is suppsed to generate a YAML datastructure that tells the rest of the helm chart how to handle this resource

### Determining relevant overrides

There are two ways you can use in the options to specify how we determine whether relevant configuration was overwritten. You can either specify the trees that should be compared:

{{- define "core-mw.typeSpecific.properties-configmap.options" -}}
usedKeys:
  - properties
  - propertiesFiles
{{- end -}}

For example says, we need a type specific version of the resource if either anything below "properties" or "propertiesFiles" has been overwritten. This only works for
top level objects.

You can also specify a template name that extracts values from a values structure to compare for finding out whether they changed. See typeSpeciic/hook-start-configmap.tpl for an example.

{{- define "core-mw.typeSpecific.hook-start-configmap.options" -}}
getValuesTemplate: "core-mw.typeSpecific.hook-start-configmap.values"
{{- end -}}

{{- define "core-mw.typeSpecific.hook-start-configmap.values" -}}
...
{{- end -}}

### The actual template

The template Template generates the actual Kubernetes resources and has access to ".Values", like normally and ".ResourceName" for its name and ".Context" for what would
normally be ".", if you need access to e.g. ".Files" that becomes ".Context.Files"


Usage:
{{- $typedResources := (include "core-mw.typedResources" . | fromYaml ) -}}


*/}}
{{- define "core-mw.typedResources" -}}
{{-   $resourceMap := dict -}}
{{-   $resourceConfig := ( include "core-mw.typedResources.resources" . | fromYaml ) -}}
{{-   $resourceList := $resourceConfig.resources -}}
{{-   $globalContext := . -}}
{{-   $scaling := (include "core-mw.scaling" . | fromYaml) -}}
{{-   range $resourceName := $resourceList -}}
{{-     $template := (printf "core-mw.typeSpecific.%s.template" $resourceName ) -}}
{{-     $resourceEntry := (dict "template" $template "values" $globalContext.Values ) -}}
{{-     $configTemplate := (printf "core-mw.typeSpecific.%s.options" $resourceName ) -}}
{{-     $globalResourceConfig := (include $configTemplate (dict "CombinedValues" $globalContext.Values "GlobalValues" $globalContext.Values "Context" $globalContext "ResourceName" $resourceName) | fromYaml ) -}}
{{-     $needsDefault := false -}}
{{-     $typesDict := dict -}}
{{-     range $typeName, $typeConfig := $scaling -}}
{{-       $combinedValues := ( include "core-mw.computeValuesFor" (dict "Context" $globalContext "Roles" $typeConfig.roles "TypeConfig" $typeConfig "TypeName" $typeName) | fromYaml ) -}}
{{-       $resourceConfig := (include $configTemplate (dict "CombinedValues" $combinedValues "GlobalValues" $globalContext.Values "TypeName" $typeName "TypeConfig" $typeConfig "Context" $globalContext "ResourceName" $resourceName) | fromYaml ) -}}
{{-       $typeDict := dict "pluginConfig" $resourceConfig -}}
{{-       if eq "true" (include "core-mw.hasTypeSpecificOverrides" (dict "CombinedValues" $combinedValues "GlobalValues" $globalContext.Values "TypeName" $typeName "TypeConfig" $typeConfig "ResourceConfig" $resourceConfig "Context" $globalContext "ResourceName" $resourceName)) -}}
{{-         $_ := set $typeDict "values" $combinedValues -}}
{{-         $_ := set $typeDict "isDefault" false -}}
{{-         $_ := set $typeDict "name" (include "core-mw.typeSpecificFullname" (dict "Context" $globalContext "TypeName" $typeName "ResourceName" $resourceName "ResourceConfig" $resourceConfig "Values" $combinedValues)) -}}
{{        else -}}
{{-         $_ := set $typeDict "values" $globalContext.Values -}}
{{-         $_ := set $typeDict "isDefault" true -}}
{{-         $_ := set $typeDict "name" (include "core-mw.typeSpecificFullname" (dict "Context" $globalContext "ResourceName" $resourceName "ResourceConfig" $resourceConfig "Values" $globalContext.Values )) -}}
{{-         $needsDefault = true -}}
{{-       end -}}
{{-       $_ := set $typesDict $typeName $typeDict -}}
{{-     end -}}
{{-     $_ := set $resourceEntry "types" $typesDict -}}
{{-     $_ := set $resourceEntry "name" (include "core-mw.typeSpecificFullname" (dict "Context" $globalContext "ResourceName" $resourceName "ResourceConfig" $globalResourceConfig "Values" $globalContext.Values )) -}}
{{-     $_ := set $resourceEntry "needsDefault" $needsDefault -}}
{{-     $_ := set $resourceMap $resourceName $resourceEntry -}}
{{    end -}}
{{    $resourceMap | toYaml }}
{{- end -}}

{{/* This template creates a data structure that contains the type individual blacklisted packages:

TYPE1:
  blacklistedPackages: "open-xchange-admin-autocontextid open-xchange-admin-reseller [...]"
  checksum: 637e5b7bb1d8cc9f641c2a98d6cc3f72d6e61f85ec95ec687750631dd93e1190
  isDefault: true
TYPE2:
  blacklistedPackages: "open-xchange-admin-reseller [...]"
  checksum: e811818f80d9c3c22d577ba83d6196788e553bb408535bb42105cdff726a60ab
  isDefault: false

Usage:
{{- $typeSpecificBundles := (include "core-mw.typeSpecificBundles" . | fromYaml ) -}}

*/}}
{{- define "core-mw.typeSpecificBundles" -}}
{{-   $typedValues := dict -}}
{{-   $globalContext := . -}}
{{-   $scaling := (include "core-mw.scaling" . | fromYaml) -}}
{{-   range $typeName, $typeConfig := $scaling -}}
{{-     $combinedValues := ( include "core-mw.computeValuesFor" (dict "Context" $globalContext "Roles" $typeConfig.roles "TypeConfig" $typeConfig "TypeName" $typeName) | fromYaml ) -}}
{{-     $typeDict := dict -}}
{{-     if eq "true" (include "core-mw.hasTypeSpecificBundles" (dict "CombinedValues" $combinedValues "GlobalValues" $globalContext.Values)) -}}
{{-       $bundleList := (include "core-mw.blacklistedPackages" $combinedValues) -}}
{{-       $_ := set $typeDict "blacklistedPackages" $bundleList -}}
{{-       $_ := set $typeDict "checksum" (sha256sum $bundleList) -}}
{{-       $_ := set $typeDict "isDefault" false -}}
{{      else -}}
{{-       $bundleList := (include "core-mw.blacklistedPackages" $globalContext.Values) -}}
{{-       $_ := set $typeDict "blacklistedPackages" $bundleList -}}
{{-       $_ := set $typeDict "checksum" (sha256sum $bundleList) -}}
{{-       $_ := set $typeDict "isDefault" true -}}
{{-     end -}}
{{-     $_ := set $typedValues $typeName $typeDict -}}
{{-   end -}}
{{    $typedValues | toYaml }}
{{- end -}}

{{/* Checks if the type or one of it's roles change the bundle set. Used internally by core-mw.typeSpecificBundles.

See "core-mw.typedResources" template for details.
 */}}
{{- define "core-mw.hasTypeSpecificBundles" -}}
{{- $context := . -}}
{{- $values := .CombinedValues -}}
{{- $globalValues := .GlobalValues -}}
{{- $hasTypeSpecificBundles := false -}}
{{- $featuresA := $values.features -}}
{{- $featuresB := $globalValues.features -}}
{{- $packagesA := $values.packages -}}
{{- $packagesB := $globalValues.packages -}}
{{- if (or (not (deepEqual $featuresA $featuresB)) (not (deepEqual $packagesA $packagesB))) -}}
{{-    $hasTypeSpecificBundles = true -}}
{{- end -}}
{{ $hasTypeSpecificBundles }}
{{- end -}}

{{/* Extracts types with a unique bundle configuration. Used internally by the update job to only create upgrade containers with a unique bundle set.

Usage:
{{- $upgradeTypes := (include "core-mw.upgradeTypes" (dict "Context" . "TypeSpecificBundles" (include "core-mw.typeSpecificBundles" .))) | fromYaml -}}
 */}}
{{- define "core-mw.upgradeTypes" -}}
{{- $context := . -}}
{{- $upgradeTypes := dict -}}
{{- $allowedTypes := $context.Context.Values.update.types -}}
{{- if not (empty $allowedTypes) -}}
{{-   range $typeName := $allowedTypes -}}
{{-     $upgradeTypes = set $upgradeTypes (printf "override-%s" $typeName) $typeName -}}
{{-   end -}}
{{- else -}}
{{-   range $typeName, $type := .TypeSpecificBundles | fromYaml -}}
{{-     if or (eq $type.isDefault false) (not (hasKey $upgradeTypes $type.checksum)) -}}
{{-       $upgradeTypes = set $upgradeTypes $type.checksum $typeName }}
{{-     end -}}
{{-   end -}}
{{- end -}}
{{ $upgradeTypes | toYaml }}
{{- end -}}

{{- define "core-mw.globalUpgradeConfig" -}}
{{- $Context := .Context -}}
{{- $UpgradeTypes := .UpgradeTypes -}}
{{- $Scaling := .Scaling -}}
{{- $TypedResources := .TypedResources -}}
{{- $UpdateValues := dict -}}
{{- if ((($Context).Values).update).values -}}
{{-   $UpdateValues = $Context.Values.update.values -}}
{{- end -}}
{{- $ValuesCache := dict -}}
{{- $ContextCache := dict -}}
{{- range $typeName, $typeConfig := $Scaling -}}
{{-   if (has $typeName (values $UpgradeTypes)) -}}
{{-     $values := (include "core-mw.computeValuesFor" (dict "Context" $Context "Roles" $typeConfig.roles "TypeConfig" $typeConfig "TypeName" $typeName) | fromYaml) -}}
{{-     $context := (dict "Roles" $typeConfig.roles "TypeConfig" $typeConfig "TypeName" $typeName "Values" $values "TypedResources" $TypedResources) -}}
{{-     $ValuesCache = (set $ValuesCache $typeName $values) -}}
{{-     $ContextCache = (set $ContextCache $typeName $context) -}}
{{-   end -}}
{{- end -}}
{{- /* ImagePullSecrets: Either the sum of all imagePullSecrets from individual type configs or overridden from Update Values */ -}}
{{- $imagePullSecrets := list -}}
{{- if $UpdateValues.imagePullSecrets -}}
{{-    $imagePullSecrets = $UpdateValues.imagePullSecrets -}}
{{- else -}}
{{-   $imagePullSecretCollector := dict -}}
{{-   range $values := $ValuesCache -}}
{{-     if $values.imagePullSecrets -}}
{{-        range $secret := $values.imagePullSecrets -}}
{{-          $_ := set $imagePullSecretCollector $secret.name $secret -}}
{{-        end -}}
{{-     end -}}
{{-   end -}}
{{-   $imagePullSecrets = values $imagePullSecretCollector -}}
{{- end -}}
{{- if eq (len $imagePullSecrets) 0 -}}
{{-   $imagePullSecrets = .Nil -}}
{{- end -}}
{{- /* NodeSelector: Either all type configs match, or overridden from Update Values or error */ -}}
{{- $nodeSelector := dict -}}
{{- if $UpdateValues.nodeSelector -}}
{{-    $nodeSelector = $UpdateValues.nodeSelector -}}
{{- else -}}
{{-   $selected := false -}}
{{-   range $typeName, $typeValues := $ValuesCache -}}
{{-      if $selected -}}
{{-        if $typeValues.nodeSelector -}}
{{-          if not (deepEqual $nodeSelector $typeValues.nodeSelector) -}}
{{-            fail (printf "NodeSelector for type %s does not match previous types" $typeName) -}}
{{-          end -}}
{{-        end -}}
{{-      else -}}
{{-        if $typeValues.nodeSelector -}}
{{-          $nodeSelector = $typeValues.nodeSelector -}}
{{-          $selected = true -}}
{{-        end -}}
{{-      end -}}
{{-   end -}}
{{- end -}}
{{- if eq (len $nodeSelector) 0 -}}
{{-   $nodeSelector = .Nil -}}
{{- end -}}
{{- /* Affinity: Either all type configs match, or overridden from Update Values or error */ -}}
{{- $affinity := dict -}}
{{- if $UpdateValues.affinity -}}
{{-    $affinity = $UpdateValues.affinity -}}
{{- else -}}
{{-   $selected := false -}}
{{-   range $typeName, $typeValues := $ValuesCache -}}
{{-      if $selected -}}
{{-        if $typeValues.affinity -}}
{{-          if not (deepEqual $affinity $typeValues.affinity) -}}
{{-            fail (printf "Affinity for type %s does not match previous types" $typeName) -}}
{{-          end -}}
{{-        end -}}
{{-      else -}}
{{-        if $typeValues.affinity -}}
{{-          $affinity = $typeValues.affinity -}}
{{-          $selected = true -}}
{{-        end -}}
{{-      end -}}
{{-   end -}}
{{- end -}}
{{- if eq (len $affinity) 0 -}}
{{-   $affinity = .Nil -}}
{{- end -}}
{{- /* TopologySpreadConstraints: Either all type configs match, or overridden from Update Values or error */ -}}
{{- $topologySpreadConstraints := list -}}
{{- if $UpdateValues.topologySpreadConstraints -}}
{{-    $topologySpreadConstraints = $UpdateValues.topologySpreadConstraints -}}
{{- else -}}
{{-   $selected := false -}}
{{-   range $typeName, $typeValues := $ValuesCache -}}
{{-      if $selected -}}
{{-        if $typeValues.topologySpreadConstraints -}}
{{-          if not (deepEqual $topologySpreadConstraints $typeValues.topologySpreadConstraints) -}}
{{-            fail (printf "TopologySpreadConstraints for type %s does not match previous types" $typeName) -}}
{{-          end -}}
{{-        end -}}
{{-      else -}}
{{-        if $typeValues.topologySpreadConstraints -}}
{{-          $topologySpreadConstraints = $typeValues.topologySpreadConstraints -}}
{{-          $selected = true -}}
{{-        end -}}
{{-      end -}}
{{-   end -}}
{{- end -}}
{{- if eq (len $topologySpreadConstraints) 0 -}}
{{-   $topologySpreadConstraints = .Nil -}}
{{- end -}}
{{- /* Tolerations: Either sum from all type configs or overridden from Update Values */ -}}
{{- $tolerations := list -}}
{{- if $UpdateValues.tolerations -}}
{{-   $tolerations = $UpdateValues.tolerations -}}
{{- else -}}
{{-   range $typeName, $typeValues := $ValuesCache -}}
{{-     if $typeValues.tolerations -}}
{{-       range $toleration := $typeValues.tolerations -}}
{{-         $found := false -}}
{{-         range $knownToleration := $tolerations -}}
{{-           if deepEqual $knownToleration $toleration -}}
{{-             $found = true -}}
{{-           end -}}
{{-         end -}}
{{-         if not $found -}}
{{-           $tolerations = append $tolerations $toleration -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- end -}}
{{- if eq (len $tolerations) 0 -}}
{{-   $tolerations = .Nil -}}
{{- end -}}
{{- /* Volumes: When volume config of volumes in each type match, deduplicate, otherwise prefix with typename */ -}}
{{- $volumes := list -}}
{{- $volumesDict := dict -}}
{{- $VolumeNameTranslationsPerType := dict -}}
{{- range $typeName, $typeValues := $ValuesCache -}}
{{-   $volumeNameTranslationDict := dict -}}
{{-   $_ := set $VolumeNameTranslationsPerType $typeName $volumeNameTranslationDict -}}
{{-   if $typeValues.extraVolumes -}}
{{-     range $volume := $typeValues.extraVolumes -}}
{{-       $volumeName := $volume.name -}}
{{-       if get $volumesDict $volumeName -}}
{{-         if not (deepEqual (get $volumesDict $volumeName) $volume) -}}
{{-           $adjustedName := (printf "%s-%s" $typeName $volumeName) -}}
{{-           $volumeCopy := deepCopy $volume -}}
{{-           $volumeCopy = set $volumeCopy "name" $adjustedName -}}
{{-           $volumeNameTranslationDict = (set $volumeNameTranslationDict $volumeName $adjustedName) -}}
{{-           $volumesDict =  (set $volumesDict $adjustedName $volumeCopy) -}}
{{-         end -}}
{{-       else -}}
{{-         $volumesDict = (set $volumesDict $volumeName $volume) -}}
{{-       end -}}
{{-     end -}}
{{-     $_ := set $typeValues "extraVolumes" nil -}}
{{-   end -}}
{{- end -}}
{{- if eq (len $volumesDict) 0 -}}
{{-   $volumes = .Nil -}}
{{- else -}}
{{-   $volumes = values $volumesDict -}}
{{- end -}}
{{- /* Containers / InitContainers: Check for sidecar containers and error out if containerType is determined to be initContainer and has sidecars */ -}}
{{- $numberOfTypes := len $ValuesCache -}}
{{- $containers := list -}}
{{- $sidecars := list -}}
{{- $index := 0 -}}
{{- range $typeName, $typeValues := $ValuesCache -}}
{{-   if $typeValues.extraMounts -}}
{{-     $volumeNameTranslationDict := get $VolumeNameTranslationsPerType $typeName -}}
{{-     range $extraMount := $typeValues.extraMounts -}}
{{-       $adjustedName := get $volumeNameTranslationDict $extraMount.name -}}
{{-       if $adjustedName -}}
{{-         set $extraMount "name" $adjustedName -}}
{{-       end  -}}
{{-     end -}}
{{-   end -}}
{{-   if (eq $index (sub $numberOfTypes 1)) -}}
{{-     $containers = append $containers (dict "Name" (printf "update-%s" $typeName) "Values" $typeValues "PartialContext" (get $ContextCache $typeName) "Type" "Container") -}}
{{-     if $typeValues.extraContainers -}}
{{-       $sidecars = $typeValues.extraContainers -}}
{{-     end -}}
{{-   else -}}
{{-     $containers = append $containers (dict "Name" (printf "update-%s" $typeName) "Values" $typeValues "PartialContext" (get $ContextCache $typeName) "Type" "InitContainer") -}}
{{-     if $typeValues.extraContainers -}}
{{-       if (gt (len $typeValues.extraContainers) 0) -}}
{{-         fail (printf "Cannot have sidecars for update container of type %s. It is not the only container providing update tasks. Set update.types to ['%s'] to run only update tasks for that container type or remove the .containers setting" $typeName $typeName) -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   $index = add1 $index -}}
{{- end -}}
{{- if eq (len $containers) 0 -}}
{{-   $containers = .Nil -}}
{{- end -}}
{{- if eq (len $sidecars) 0 -}}
{{-   $sidecars = .Nil -}}
{{- end -}}
{{- dict "ImagePullSecrets" $imagePullSecrets "NodeSelector" $nodeSelector "Affinity" $affinity "TopologySpreadConstraints" $topologySpreadConstraints "Tolerations" $tolerations "Containers" $containers "Sidecars" $sidecars "ExtraVolumes" $volumes | toYaml -}}
{{- end -}}

{{/*
Determines the scaling and node type configuration for the middleware. Looks for .Values.replicas, but if not set falls back to .Values.defaultScaling with .Values.replicas as the replication value.
This means complex clusters can specify individual groupware node types and scale them individually while more trivial clusters only need to specify .Values.replicas
Usage:
{{- $scaling := (include "core-mw.scaling" . | fromYaml) -}}
*/}}
{{- define "core-mw.scaling" -}}
{{- $scaling := .Values.defaultScaling.nodes | deepCopy -}}
{{- $_ := set $scaling.default "replicas" .Values.replicas -}}
{{- if .Values.scaling -}}
{{- $scaling = .Values.scaling.nodes | deepCopy -}}
{{- end -}}
{{ toYaml $scaling }}
{{- end -}}

{{/* Checks whether, for a certain kubernetes resource, the type or one of the types roles overwrites relevant parts of the configuration. Used internally by core-mw.typedResources.
To determine if the configuration changed it either uses the list under `usedKeys` from the resources options template (e.g. core-mw.typeSpecific.as-config-configmap.options in typeSpecific/as-config-configmap.yaml) or
calls the template specified in getValuesTemplate to extract values to compare (See for example typeSpecific/hook-before-start-configmap.yaml)

See "core-mw.typedResources" template for details.
 */}}
{{- define "core-mw.hasTypeSpecificOverrides" -}}
{{- $context := . -}}
{{- $values := .CombinedValues -}}
{{- $globalValues := .GlobalValues -}}
{{- $resourceConfig := .ResourceConfig -}}
{{- $hasTypeSpecificOverrides := false -}}
{{- if $resourceConfig.usedKeys -}}
{{-   range $key := $resourceConfig.usedKeys -}}
{{-     $valuesA := get $values $key -}}
{{-     $valuesB := get $globalValues $key -}}
{{-     if (not (deepEqual $valuesA $valuesB)) -}}
{{-        $hasTypeSpecificOverrides = true -}}
{{-     end -}}
{{-   end -}}
{{- end -}}
{{- if $resourceConfig.getValuesTemplate -}}
{{-   $valuesA := (include $resourceConfig.getValuesTemplate (dict "Values" $values) | fromYaml) -}}
{{-   $valuesB := (include $resourceConfig.getValuesTemplate (dict "Values" $globalValues) | fromYaml) -}}
{{-   if (not (deepEqual $valuesA $valuesB)) -}}
{{-      $hasTypeSpecificOverrides = true -}}
{{-   end -}}
{{- end -}}
{{ $hasTypeSpecificOverrides }}
{{- end -}}


{{/* Computes either a type-specific or the default name. Used internally to build datastructure in core-mw.typedResources

See core-mw.resourceName for how to get the chosen name from that datastructure
See core-mw.typedResources for a general explanation of the type/role system
 */}}
{{- define "core-mw.typeSpecificFullname" -}}
{{- if .ResourceConfig.nameTemplate -}}
{{ include .ResourceConfig.nameTemplate (dict "Values" .Values "Context" .Context "TypeName" .TypeName "ResourceName" .ResourceName ) }}
{{- else -}}
{{- if .TypeName -}}
{{ include "ox-common.names.fullname" .Context }}-{{ .TypeName }}-{{ .ResourceName }}
{{- else -}}
{{ include "ox-common.names.fullname" .Context }}-{{ .ResourceName }}
{{- end -}}
{{- end -}}
{{- end -}}


{{/* Extract a resources names from the data structure returned by core-mw.typedResources. This is either the default resource (e.g. RELEASE-NAME-as-config-configmap ) or
a type specific name (e.g. RELEASE-NAME-TYPE-NAME-as-config-configmap) if either the type or one of its roles overwrites the configuration that have to do with that resource.
See: "core-mw.typedResources" for more details.

Usage:
  {{ include "core-mw.resourceName" (dict "DeploymentContext" (dict "TypedResources" $typedResources "TypeName" "http-api") "ResourceName" "as-config-configmap") }}
 */}}
{{- define "core-mw.resourceName" -}}
{{- $resourceConfig := .DeploymentContext.TypedResources -}}
{{- $typeName := .DeploymentContext.TypeName -}}
{{- $resourceName := .ResourceName -}}
{{- $resourceEntry := get $resourceConfig $resourceName -}}
{{ get (get $resourceEntry.types $typeName) "name" }}
{{- end -}}

{{- define "core-mw.redis" -}}
  {{- printf "%s-redis" (include "ox-common.names.fullname" .) -}}
{{- end -}}

{{- define "core-mw.redis.hosts" -}}
{{- $redisHosts := include "ox-common.redis.hosts" (dict "redis" .Values.redis "context" .) -}}
{{- if empty $redisHosts -}}
{{ printf "%s:6379" (include "core-mw.redis" . ) }}
{{- else -}}
{{ $redisHosts }}
{{- end -}}
{{- end -}}

{{/*
Specifies properties which are added to a StatefulSet.
*/}}
{{- define "core-mw.statefulSetProperties" -}}
{{- $context := . -}}
podManagementPolicy: {{ .Values.extraStatefulSetProperties.podManagementPolicy | default "OrderedReady" }}
volumeClaimTemplates: {{ .Values.extraStatefulSetProperties.volumeClaimTemplates | default list | toYaml | nindent 2 }}
{{- end -}}

{{/*
Checks if the init container is enabled or not
*/}}
{{- define "core-mw.init.enabled" -}}
{{- if or .enableInitialization .enableDBConnectionCheck .javaOpts.debug.heapdump.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "daily_scan_cron_tab_seed" -}}
  {{- printf "%s/%s/%s" .Values.clusterName .Release.Namespace .Release.Name -}}
{{- end -}}

{{- define "daily_scan_cron_tab_minute" -}}
  {{- $hash := sha256sum (printf "minute-%s" (include "daily_scan_cron_tab_seed" .)) -}}
  {{- $digits := mustRegexFind "[0-9]+" $hash -}}
  {{- mod (atoi (trunc 4 $digits)) 60 -}}
{{- end -}}

{{- define "daily_scan_cron_tab_hour" -}}
  {{- $hash := sha256sum (printf "hour-%s" (include "daily_scan_cron_tab_seed" .)) -}}
  {{- $digits := mustRegexFind "[0-9]+" $hash -}}
  {{- mod (atoi (trunc 4 $digits)) 24 -}}
{{- end -}}

{{/* calc values for kubescape cronjobs */}}
{{- define "kubescape_daily_scan_cron_tab" -}}
  {{- if eq .Values.kubescapeScheduler.scanSchedule "0 8 * * *" -}}
    {{- $existingSchedule := (lookup "batch/v1" "CronJob" .Values.ksNamespace .Values.kubescapeScheduler.name) -}}
    {{- if $existingSchedule -}}
      {{ $existingSchedule.spec.schedule }}
    {{- else -}}
      {{- $daily_scan_cron_tab_minute := (include "daily_scan_cron_tab_minute" .) -}}
      {{- $daily_scan_cron_tab_hour := (include "daily_scan_cron_tab_hour" .) -}}
      {{ trimPrefix "\n" (trimSuffix  "\n" $daily_scan_cron_tab_minute) }} {{ trimPrefix "\n" (trimSuffix  "\n" $daily_scan_cron_tab_hour) }} * * *
    {{- end -}}
  {{- else -}}
    {{- .Values.kubescapeScheduler.scanSchedule -}}
  {{- end -}}
{{- end }}

{{/* calc values for kube-vuln cronjobs */}}
{{- define "kubevuln_daily_scan_cron_tab" -}}
  {{- if eq .Values.kubevulnScheduler.scanSchedule "0 0 * * *" -}}
    {{- $existingSchedule := (lookup "batch/v1" "CronJob" .Values.ksNamespace .Values.kubevulnScheduler.name) -}}
    {{- if $existingSchedule -}}
      {{ $existingSchedule.spec.schedule }}
    {{- else -}}
      {{- $daily_scan_cron_tab_minute := (include "daily_scan_cron_tab_minute" .) -}}
      {{- $daily_scan_cron_tab_hour := (include "daily_scan_cron_tab_hour" .) -}}
      {{ trimPrefix "\n" (trimSuffix  "\n" $daily_scan_cron_tab_minute) }} {{ trimPrefix "\n" (trimSuffix  "\n" $daily_scan_cron_tab_hour) }} * * *
    {{- end -}}
  {{- else -}}
    {{- .Values.kubevulnScheduler.scanSchedule -}}
  {{- end -}}
{{- end }}

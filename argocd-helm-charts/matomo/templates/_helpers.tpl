{{- define "matomo.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end }}

{{- define "matomo.hosts" -}}
{{ prepend .Values.extraHosts .Values.host | toJson }}
{{- end }}

{{- define "matomo.env" -}}
- name: MATOMO_PLUGIN_DIRS
  value: /var/www/html/extra-plugins/;extra-plugins
- name: MATOMO_PLUGIN_COPY_DIR
  value: /var/www/html/extra-plugins/
{{- end }}

{{- define "matomo.volumeMounts" -}}
- name: code
  mountPath: /var/www/html
- name: state
  mountPath: /var/www/html/config
  subPath: config
- name: state
  mountPath: /var/www/html/misc
  subPath: misc
- name: state
  mountPath: /var/www/html/extra-plugins
  subPath: plugins
{{- end }}

{{- define "matomo.volumes" -}}
- name: code
  emptyDir: {}
- name: state
  persistentVolumeClaim:
    claimName: matomo
{{- end }}

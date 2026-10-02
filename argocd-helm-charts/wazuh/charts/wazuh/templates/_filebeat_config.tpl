{{/* vim: set filetype=mustache: */}}
{{- define "wazuh.filebeat_config" -}}
# Wazuh - Filebeat configuration file
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: {{ if include "wazuh.archives.enabled" . }}true{{ else }}false{{ end }}
{{- if include "wazuh.indexRouting.enabled" . }}

# The alerts pipeline is mounted over the module's own (tenant index routing). Filebeat
# only uploads a pipeline the indexer does not have yet unless told to overwrite, so
# without this the stock pipeline already in the indexer would stay in use.
filebeat.overwrite_pipelines: true
{{- end }}

setup.template.json.enabled: true
setup.template.overwrite: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.enabled: false
output.elasticsearch:
  hosts: ['https://wazuh.indexer:9200']
  #username:
  #password:
  #ssl.verification_mode:
  #ssl.certificate_authorities:
  #ssl.certificate:
  #ssl.key:

logging.metrics.enabled: false

seccomp:
  default_action: allow
  syscalls:
  - action: allow
    names:
    - rseq
{{ end -}}

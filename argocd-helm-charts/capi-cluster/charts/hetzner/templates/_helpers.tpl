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

{{/* Put the UEFI PXE IPv4 entry first in the boot order, so CAPH can boot the server into
     the Hetzner rescue system. When no rescue is activated, UEFI PXE gets nothing to boot
     and the firmware moves on to the next entry, the installed OS.

     Only a UEFI entry qualifies, matched on its device path (MAC(...)/IPv4(...), and no
     Uri(...), which would be HTTP boot). Matching on the entry name ("Network Card",
     "Network Connection") also picks the legacy CSM entry, BBS(Network,...), on boards
     that have one. That legacy PXE ROM exits with "PXE-M0F: Exiting PXE ROM" and the
     firmware does not fall through to the UEFI OS entry, so the server hangs on its
     first reboot after the install.

     Without a UEFI PXE IPv4 entry the boot order is left as it is: UEFI network boot is
     off in the BIOS and has to be enabled there (Hetzner support), or CAPH cannot boot
     the server into rescue for a reinstall. */}}
{{- define "hetzner.efiBootOrderScript" -}}
if [ ! -d /sys/firmware/efi ]; then
  echo "legacy BIOS boot — skipping EFI boot-order adjustment"
else
  NETBOOT=$(efibootmgr -v \
    | grep -E '^Boot[0-9A-F]{4}' \
    | grep 'MAC(' | grep 'IPv4(' | grep -v 'Uri(' \
    | sed 's/^Boot\([0-9A-F]\{4\}\).*/\1/' \
    | head -n1)
  if [ -z "$NETBOOT" ]; then
    echo "no UEFI PXE IPv4 boot entry found — leaving the boot order unchanged"
    echo "enable UEFI network boot in the BIOS, otherwise CAPH cannot boot this server into rescue"
  else
    CURRENT_ORDER=$(efibootmgr | grep "BootOrder:" | cut -d' ' -f2)
    NEW_ORDER=$(echo "$CURRENT_ORDER" | sed "s/$NETBOOT,\?//g" | sed "s/^/$NETBOOT,/" | sed 's/,$//')
    efibootmgr -o "$NEW_ORDER"
  fi
fi
{{- end -}}

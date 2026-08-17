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

{{/* Give highest priority to the Network Card / Connection entry in the boot order.
     Otherwise, we cannot boot the servers into rescue mode, and need to reach out to the
     Hetzner support team. */}}
{{- define "hetzner.efiBootOrderScript" -}}
if [ ! -d /sys/firmware/efi ]; then
        echo "legacy BIOS boot — skipping EFI boot-order adjustment"
else
  NETBOOT=$(efibootmgr -v \
    | grep -E "Network (Card|Connection|Device)" \
    | sed 's/Boot\([0-9A-F]*\).*/\1/' \
    | head -n1)
  if [ -z "$NETBOOT" ]; then
    echo "no EFI network boot entry found — skipping boot-order adjustment"
  else
    CURRENT_ORDER=$(efibootmgr | grep "BootOrder:" | cut -d' ' -f2)
    NEW_ORDER=$(echo "$CURRENT_ORDER" | sed "s/$NETBOOT,\?//g" | sed "s/^/$NETBOOT,/" | sed 's/,$//')
    efibootmgr -o "$NEW_ORDER"
  fi
fi
{{- end -}}

{{/* Set NETWORK_INTERFACE to the NIC carrying the default route.
     cloud-init's runcmd can start before networking is up — `ip route get`
     then fails with "Network is unreachable" and NETWORK_INTERFACE ends up
     empty. Callers interpolate it into netplan (`link: ${NETWORK_INTERFACE}`),
     so an empty value yields "interface '' is not defined", netplan apply
     fails, the node never gets its vSwitch address, and kubeadm join times
     out against the private API endpoint. Observed consistently on Ubuntu
     26.04, which brings networking up later than 24.04 did.
     So: wait for the default route, and abort loudly rather than write an
     invalid netplan. */}}
{{- define "hetzner.detectNetworkInterfaceScript" -}}
NETWORK_INTERFACE=""
attempt=0
while [ "$attempt" -lt 60 ]; do
  NETWORK_INTERFACE="$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')"
  if [ -n "$NETWORK_INTERFACE" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done
if [ -z "$NETWORK_INTERFACE" ]; then
  echo "ERROR: no default route after 120s — cannot determine the primary network interface" >&2
  exit 1
fi
export NETWORK_INTERFACE
echo "detected primary network interface: $NETWORK_INTERFACE"
{{- end -}}

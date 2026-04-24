{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'baremetal-node-labels',
        rules: [
          {
            alert: 'BareMetalNodeLabelsMissingOrMismatch',
            expr: 'absent(kube_node_labels) or (kube_node_labels{label_beta_kubernetes_io_instance_type!~"^(cax|cx|cpx|ccx).*"} unless kube_node_labels{label_kubernetes_io_hostname=~"^bm-.*-[0-9]{7}$"})',
            'for': '10m',
            labels: {
              severity: 'warning',
              alert_id: 'BareMetalNodeLabelsMissingOrMismatch',
            },
            annotations: {
              summary: 'Bare-metal node labels missing or incorrect.',
              description: 'Node {{ $labels.node }} with hostname "{{ $labels.label_kubernetes_io_hostname | or "not set" }}" does not follow the required naming pattern. Bare-metal nodes must use consistent hostnames matching bm-*-[0-9]{7} (e.g., bm-worker-1234567) to prevent CAPI from restarting nodes, which would cause PVC attachment failures.',
            },
          },
        ],
      },
    ],
  },
}

<!--
SPDX-FileCopyrightText: 2023 Bundesministerium des Innern und für Heimat, PG ZenDiS "Projektgruppe für Aufbau ZenDiS"

SPDX-License-Identifier: Apache-2.0
-->
{{ template "chart.header" . }}
{{ template "chart.description" . }}

## Installing the Chart

To install the chart with the release name `my-release`:

```console
helm repo add ${CI_PROJECT_NAME} ${CI_SERVER_PROTOCOL}://${CI_SERVER_HOST}/api/v4/projects/${CI_PROJECT_ID}/packages/helm/stable
helm install my-release ${CI_PROJECT_NAME}/{{ template "chart.name" . }}
```

{{ template "chart.requirementsSection" . }}

{{ template "chart.valuesSection" . }}

## Making coturn available to the Internet

Currently, there are 2 options supported: `LoadBalanacer` and `NodePort`. Depending on your cluster/network setup, there might be also other options which are not described in this readme.

### Option 1: service of type `LoadBalancer`

This requires a cloud setup that enables a Loadbalancer attachement. This could be enabled via values:

```yaml
service:
  type: "LoadBalancer"

# all ports specified here will be available on the LoadBalancer:
coturn:
  # -- listening Port (TCP & UDP)
  listeningPort: 3478
  tls:
    # -- enable TLS
    enabled: true
    # -- TLS Port (TCP & UDP)
    listeningPort: 5349
  # -- lower bound of the UDP relay endpoints
  minPort: 49152
  # -- upper bound of the UDP relay endpoints
  maxPort: 65535
```

### Option 2: NodePort with NAT (Network Address Translation) and PAT (Port Address Translation)

This setup requires an external firewall or loadbalancer with a public IP and port translation from the specified ports on the external IP to the corresponding NodePorts on the internal Node IPs.

```yaml
service:
  type: "NodePort"
  # -- to which NodePort is the external Listening Port fowarded?
  # only needed if type is NodePort
  listeningNodePort: 31478
  # -- to which Node Port is the external TLS Listening Port forwarded?
  # only needed if type is NodePort
  tlsListeningNodePort: 31549
  # -- starting NodePort of the UDP Relay Endpoints
  # only needed if type is NodePort
  minNodePort: 30500

# all ports specified here will be available on corresponding NodePort:
coturn:
  # -- listening Port (TCP & UDP)
  listeningPort: 3478
  tls:
    # -- enable TLS
    enabled: true
    # -- TLS Port (TCP & UDP)
    listeningPort: 5349
  # -- lower bound of the UDP relay endpoints
  minPort: 30500
  # -- upper bound of the UDP relay endpoints
  maxPort: 30550
```

## Uninstalling the Chart

To install the release with name `my-release`:

```bash
helm uninstall my-release
```

## Signing

Helm charts are signed with helm native signing method.

You can verify the chart against [the public GPG key](../../files/gpg-pubkeys/opendesk.gpg).

## License

This project uses the following license: Apache-2.0

## Copyright

Copyright (C) 2023 Bundesministerium des Innern und für Heimat, PG ZenDiS "Projektgruppe für Aufbau ZenDiS"

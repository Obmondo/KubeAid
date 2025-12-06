<!--
SPDX-FileCopyrightText: 2024 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
-->
{{ template "chart.header" . }}
{{ template "chart.description" . }}

## Installing the Chart

To install the chart with the release name `my-release`, you have two options:

### Install via Repository
```console
helm repo add ${CI_PROJECT_NAME} ${CI_SERVER_PROTOCOL}://${CI_SERVER_HOST}/api/v4/projects/${CI_PROJECT_ID}/packages/helm/stable
helm install my-release --version ${RELEASE_VERSION} ${CI_PROJECT_NAME}/{{ template "chart.name" . }}
```

### Install via OCI Registry
```console
helm repo add ${CI_PROJECT_NAME} oci://${CI_REGISTRY_IMAGE}
helm install my-release --version ${RELEASE_VERSION} ${CI_PROJECT_NAME}/{{ template "chart.name" . }}
```

{{ template "chart.requirementsSection" . }}

{{ template "chart.valuesSection" . }}

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

Copyright (C) 2024 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH

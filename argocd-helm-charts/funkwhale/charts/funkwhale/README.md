Funkwhale
=========

[Funkwhale](https://funkwhale.audio/) is a community-driven project that lets you listen and share music and audio within a decentralized, open network.

## Installing

A minimal Funkwhale install could look like;

    helm install funkwhale ananace-charts/funkwhale --set ingress.enabled=true,ingress.host=funkwhale.example.com

Though using HTTPS might be necessary if you wish to be able to federate with other Funkwhale instances - commonly referred to as pods.

    helm install funkwhale ananace-charts/funkwhale --set ingress.enabled=true,ingress.host=funkwhale.example.com,ingress.protocol=https,ingress.tls[0].hosts[0]=funkwhale.example.com,ingress.tls[0].secretName=funkwhale-tls

<!-- markdownlint-disable-file MD041 -->
<!-- markdownlint-disable MD033 -->
<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Obmondo/KubeAid/master/docs/images/kubeaid-logo-dark.svg">
  <img alt="KubeAid" src="https://raw.githubusercontent.com/Obmondo/KubeAid/master/docs/images/kubeaid-logo.svg" width="380">
</picture>

*Open-source Kubernetes platform: install and operate clusters the same way everywhere —*
*with the ecosystem's churn handled for you.*

[![Latest Release](https://img.shields.io/github/v/release/Obmondo/KubeAid?sort=semver&label=release)](https://github.com/Obmondo/KubeAid/releases)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-orange)](LICENSE)
[![Stars](https://img.shields.io/github/stars/Obmondo/KubeAid?label=stars)](https://github.com/Obmondo/KubeAid/stargazers)
[![Contributors](https://img.shields.io/github/contributors/Obmondo/KubeAid)](https://github.com/Obmondo/KubeAid/graphs/contributors)
[![Issues](https://img.shields.io/github/issues/Obmondo/KubeAid)](https://github.com/Obmondo/KubeAid/issues)
[![Last Commit](https://img.shields.io/github/last-commit/Obmondo/KubeAid)](https://github.com/Obmondo/KubeAid/commits/master)

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Obmondo/KubeAid)
[![Release Build](https://github.com/Obmondo/KubeAid/actions/workflows/release.yaml/badge.svg)](https://github.com/Obmondo/KubeAid/actions/workflows/release.yaml)
[![Chart Updates](https://github.com/Obmondo/KubeAid/actions/workflows/update-helm-chart.yml/badge.svg)](https://github.com/Obmondo/KubeAid/actions/workflows/update-helm-chart.yml)

[**Documentation**](https://kubeaid.io/docs/)
· [**Getting Started**](https://kubeaid.io/docs/getting-started/)
· [**Why KubeAid?**](https://kubeaid.io/docs/kubeaid/why-kubeaid)
· [**Roadmap**](./ROADMAP.md)

</div>
<!-- markdownlint-enable MD033 -->

---

Running Kubernetes means tracking a moving ecosystem: charts get deprecated, APIs break, defaults turn out to be
security risks. **KubeAid carries that overhead for you** — a curated stack of 100+ vendored Helm charts with tested
defaults, shipped as reviewed updates you pull when it suits you. Nothing is fetched live from upstream at deploy
time: what you deploy is exactly what was reviewed. Runs everywhere: AWS and Azure (self-managed, or managed
EKS/AKS), Hetzner, bare metal, or locally on K3D.

This repository holds the platform itself — curated Helm charts, monitoring, and secure defaults. It is consumed by
the **[KubeAid CLI](https://github.com/Obmondo/kubeaid-cli)**, which is the tool you actually run to create and manage
clusters.

## Table of Contents

- [What Exactly Is KubeAid?](#what-exactly-is-kubeaid)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Features](#features)
- [Design Decisions](./docs/kubeaid/decisions.md) — why Helm and YAML, and the other choices we've made
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Community and Governance](#community-and-governance)
- [Roadmap](ROADMAP.md)
- [Support](#support)
- [License](#license)

## What Exactly Is KubeAid?

Installing Kubernetes looks easy until you do it on a second platform. AWS wants IAM roles, Azure wants Workload
Identity, Hetzner and bare metal have their own models — and that's before monitoring, ingress, storage, and upgrades.
KubeAid removes the per-platform relearning: one workflow, one repository layout, one set of defaults, everywhere.

It is three pieces that work together:

1. **This repository (KubeAid)** — the platform definition: an ever-expanding catalogue of 100+ maintained Helm
   chart wrappers in [`argocd-helm-charts/`](./argocd-helm-charts/), with tested default values and automated weekly
   updates, plus [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) monitoring generated with
   [Jsonnet](https://jsonnet.org/). This makes KubeAid an application platform, not just an installer — each app is
   extended and integrated beyond its upstream chart:
   - **Central operators** manage common resources — databases (PostgreSQL, MariaDB, MongoDB), message queues
     (Kafka, RabbitMQ), Redis, backups — instead of per-app one-off setups.
   - **Principle of least privilege** — application-level network policies restrict apps to exactly the traffic
     they need.
   - **Single sign-on** — [Keycloak](./argocd-helm-charts/keycloakx/) SSO integration documented for supported
     apps.
   - **Operational procedures** — documented optimal configuration, backup and restore, and solutions to
     challenges already encountered.

   You don't run anything from here directly — it is consumed by the KubeAid CLI,
   and later by ArgoCD, straight from upstream by default. For production we recommend mirroring it into your own
   Git platform, so you keep full control even if access to the upstream repository is ever lost.
2. **[KubeAid CLI](https://github.com/Obmondo/kubeaid-cli)** — the entry point. A command-line tool you run once per
   cluster: it consumes this repository, generates your configuration, and bootstraps the cluster using
   [Cluster API](https://cluster-api.sigs.k8s.io/) (or [KubeOne](https://github.com/kubermatic/kubeone) for SSH-only
   bare metal).
3. **Your `kubeaid-config` repository** — created from the
   [sample template](https://github.com/Obmondo/kubeaid-config) and filled in during bootstrap; holds all your
   cluster-specific settings, layered on top of the KubeAid platform defaults. ArgoCD inside the cluster watches it
   and applies changes, so Git is the single source of truth for everything running in the cluster.

Every KubeAid cluster ships with [Cilium](https://cilium.io/) (kube-proxyless),
[ArgoCD](https://argo-cd.readthedocs.io/), [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets/), and
kube-prometheus. By default, auto-sync is not enabled, so you decide when changes are applied; you can turn it on per
application if you prefer automated deployments.

## How It Works

You commit to your `kubeaid-config` repository, and ArgoCD inside the cluster continuously pulls charts from KubeAid
and your values from `kubeaid-config`, reconciling the platform stack and your applications. The KubeAid CLI runs
once to bootstrap: it writes your initial config, provisions the cluster, and pivots Cluster API into it:

<!-- markdownlint-disable MD033 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Obmondo/KubeAid/master/docs/images/kubeaid-architecture-dark.svg">
  <img alt="KubeAid architecture diagram: the operator pushes to kubeaid-config; Argo CD in the cluster pulls charts
    from the KubeAid repo and values from kubeaid-config, applying the platform stack and your applications; the
    KubeAid CLI runs once to bootstrap and pivot Cluster API into the cluster"
    src="https://raw.githubusercontent.com/Obmondo/KubeAid/master/docs/images/kubeaid-architecture.svg">
</picture>
<!-- markdownlint-enable MD033 -->

One rule to know up front: if you run a KubeAid mirror, never commit directly to its master/main branch — that
branch is how updates are delivered to you, so keeping it clean means updating your cluster is as simple as a
`git pull`.

## Quick Start

```sh
# Install the KubeAid CLI (x86_64/arm64, Linux and macOS)
curl -fsSL https://raw.githubusercontent.com/Obmondo/kubeaid-cli/main/scripts/install.sh | sh

# Interactive prompt walks you through cluster name, platform
# (local K3D, AWS, Azure, Hetzner, bare metal) and everything else
kubeaid-cli config generate

# Review the generated config, then bring the cluster up
kubeaid-cli cluster bootstrap --cluster-name <cluster>
```

Your answers land under `~/.config/kubeaid-cli/<cluster>/configs` (use `--configs-directory` to choose another
location). Other install methods (Nix, Homebrew, from source) are in the
[KubeAid CLI README](https://github.com/Obmondo/kubeaid-cli#installation).

Choosing local K3D gives you a playground on your own machine — the workflow is identical to a production cloud
cluster. The **[Getting Started Guide](./docs/getting-started/README.md)** walks through prerequisites, configuration, installation,
and day-2 operations for every supported platform.

## Features

- **No-mental-overhead updates**: we track what's broken, deprecated, or superseded across the whole stack, and ship
  tested chart and security updates weekly — ready to be applied to your clusters at will, so you can focus on your
  own applications.
- **Multi-cloud installation**: self-managed clusters on AWS, Azure, Hetzner, and bare metal; managed control planes
  on [EKS](https://aws.amazon.com/eks/) and
  [AKS](https://azure.microsoft.com/en-us/products/kubernetes-service); hybrid Hetzner Bare Metal + HCloud clusters.
  One install method, any target.
- **GitOps everything**: all cluster changes go through Git, and drift is detected if anyone changes resources
  directly in the cluster.
- **Curated application catalogue**: an ever-growing list of open-source Kubernetes applications in
  [`argocd-helm-charts/`](./argocd-helm-charts/), each wrapped with default values that follow current best practices.
  Upstream charts are vendored into this repository, so what you deploy is exactly what was reviewed — a defence
  against supply-chain attacks, backed by frequent security scans of all software used in the clusters.
- **Monitoring built in**: advanced, customised Prometheus monitoring from a per-cluster config file, with automated
  handling of trivial alerts like disks filling up.
- **Secrets in Git, safely**: [sealed-secrets](./argocd-helm-charts/sealed-secrets/README.md) encrypts secrets locally
  before they are committed to your config repository.
- **Unified access management**: cluster access runs over the [NetBird](https://netbird.io/) mesh with
  [Keycloak](https://www.keycloak.org/) as the SSO identity provider by default. Teleport remains available as an
  optional, deprecated alternative.
- **Cluster security**: NetworkPolicies enforce least privilege between applications and secure intra-cluster and
  ingress traffic.
- **Lifecycle operations**: auto-scaling, backup and recovery, live migration of applications or whole clusters, major
  upgrades via a parallel shadow cluster, and [air-gapped
  operation](https://kubernetes.io/blog/2023/10/12/bootstrap-an-air-gapped-cluster-with-kubeadm/).
- **Compliance by default**: security and operational defaults mapped to ISO 27001:2022, covering GDPR and NIS2 goals.

The implementation status of each feature is documented in
[Technical Details on the Features](./docs/kubeaid/features-technical-details.md); planned work lives in the
[Roadmap](ROADMAP.md).

## Documentation

You can find the documentation, guides and tutorials in the [`/docs`](./docs/) directory.

## Contributing

Contributions are welcome — bug reports, chart updates, new providers, and documentation alike. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for the workflow; note that commits need a DCO sign-off (`git commit -s`).

## Community and Governance

- [Code of Conduct](CODE_OF_CONDUCT.md) — we follow the CNCF Community Code of Conduct.
- [Governance](GOVERNANCE.md) — how decisions are made and how maintainers are added.
- [Maintainers](MAINTAINERS.md) — current maintainers of the project.
- [Adopters](ADOPTERS.md) — organizations running KubeAid; add yours with a PR.
- [Security policy](SECURITY.md) — how to report vulnerabilities privately.

## Support

Community support happens through the issue tracker and the `#kubeaid` channel on
[Kubernetes Slack](https://slack.k8s.io/) (get an invite there if you're not a member yet). Besides that,
[Obmondo](https://obmondo.com) (the primary developers of this project) offers professional support: we can observe
your clusters, react to your alerts, and help you develop new features on clusters set up using this project.

There is zero vendor lock-in — KubeAid works the same with or without a support agreement, and any agreement can be
cancelled at any time.

## License

**KubeAid** is licensed under the [Affero GPLv3 license](LICENSE), as we believe this is the best way to protect
against the patent attacks we see hurting the industry; where companies submit code that uses technology they have
patented, and then turn and litigate companies that use the software.

The Affero GNU Public License has always been focused on ensuring everyone gets the same privileges, protecting against
methods like [TiVoization](https://en.wikipedia.org/wiki/Tivoization), which means it's very much aligned with the goals
of this project, namely to allow everyone to work on a level playing ground.

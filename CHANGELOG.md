# Changelog

All releases and the changes included in them (pulled from git commits added since last release) will be detailed in this file.

## KubeAid Release Version 24.1.1

### Features
- c7b727b6a feat(erpnext): add podMetadata support to MariaDB template for velero backup annotations

### Other Changes
- 39f963fb4 update release.md with edgecase of new release without helm update
- 9d12ce359 Fix kyverno chart breaking the helm template

## KubeAid Release Version 24.1.0

### Bug Fixes
- edfe138b8 fix: alert expression fixed to look only tag and fixed the prom reporter to read all the environment
- de260b819 fix: add secret references for hostkey and sshprivatekey for kubeaid agent
- 75dd30d6a fix broken helm render

### Configuration Changes
- b00ff82dc chore: update k8s act runner image version to dind-0.3.0
- dded72f0a chore: update netbird image version to latest
- dd045bf9e chore(doc): updated git commit msg for changelog update

### Other Changes
- 9505fc107 add ports config back to traefik
- db185449f add backup and restore section in opendesk readme
- ee315bcbf update build.sh to render specific applicationa and updated opendesk doc
- 3c29b508d update script to use latest version
- 22d440a87 enable Jibri and override JVB STUN servers
- c46cff50d add v1.11.4
- da52b66ff Increase default memory req and limit for argocd controller
- 931666bc7 Add CONTRIBUTING.md community guidelines

## KubeAid Release Version 24.0.1

### Bug Fixes
- 67d95252d fix: lets take tag from positional args, if none given, pick from the VERSION file

### Other Changes
- 1e9260f30 remove deprecated traefik values

## KubeAid Release Version 24.0.0

### New Charts Added
- ecc532894 chore(new): Added new helm chart garage 0.2.1
- 81d5d6027 chore(new): Added new helm chart calcom 0.8.6

### Features
- a2905d029 feat: add support for HPA maxed out alerts and update prometheus rule filtering
- 2fc829267 feat(capi-cluster/hetzner): allow disabling public IPs for HCloud instances
- 6652e112b feat: added garage helm chart manually from a git clone
- edd6c8f96 feat: add ingress-only cilium netpols for ciso-assistant frontend and backend
- 9f657aa9a feat: added release doc

### Bug Fixes
- 5263a98d0 fix in the hardcoded namespace
- c84ab227f fix: typo in doc and renamed the readme files
- bc7f0acb7 fix(ci): add credentials for pulling private ci image
- 92a54328b fix(capi-cluster/hetzner): applying constant-hostnames annotation to the Cluster resource
- 77a96ab15 fix the logs/errors of the pod

### Configuration Changes
- ffb9ddd25 chore: add kubeaid agent helm chart

### Other Changes
- 8405e64b4 upgrade traefik chart and fix update script
- 3d8507cef remove traefik and fix argocd from helm cache
- b3ae470c9 Upgrade helm charts
- b098899e1 add docs for mac os release
- 3aa581ed1 add doc for odoo user password reset
- 822aaa882 Upgraded postgres logical backup to latest in Odoo
- 7e86090d2 add if else block to the fileStore for mattermost
- 5657137bc Update procedure to restore cloudnative DB
- ae947a8b0 add documentation for Keycloak webhook event integration
- aa16d067c Tested and Updated mastodon, pixelfed, peertube pgsql cronjob template
- e40bf3152 Added s3 config secret management tips in seaweedfs docs
- 6b5cc48c8 Remove pinned version of autoscaler
- 051a6a6dc docs: Add comprehensive KubeAid cluster design guide
- 3fc8869b8 Revert "fix the logs/errors of the pod"
- ce1d3e7fc remove: redundant toServices rule for Kubernetes API
- 70287ea43 Fix HPA template to use autoscaling/v2 API instead of deprecated v2beta1
- 8184cde87 Adding Cal.com Helm Chart

## KubeAid Release Version 23.0.0

### New Charts Added
- 07c0076c9 chore(new): Added new helm chart castopod 1.12.10
- 7aa0b82db chore(new): Added new helm chart lemmy 0.6.10

### Major Version Upgrades
- 2ffbe15ad Updated snapshot-controller from version 4.2.0 to 5.0.1

### Minor Version Upgrades
- 2ffbe15ad Updated opentelemetry-collector from version 0.142.2 to 0.143.0
- 2ffbe15ad Updated redis-operator from version 0.22.2 to 0.23.0
- 2ffbe15ad Updated strimzi-kafka-operator from version 0.49.1 to 0.50.0
- 2ffbe15ad Updated traefik-forward-auth from version <empty string> to 0.3.10

### Patch Version Upgrades
- 2ffbe15ad Updated mariadb-operator from version 25.10.3 to 25.10.4
- 2ffbe15ad Updated mattermost-team-edition from version 6.6.89 to 6.6.90
- 2ffbe15ad Updated opencost from version 2.5.1 to 2.5.3
- 2ffbe15ad Updated rook-ceph-cluster from version v1.18.8 to v1.18.9
- 2ffbe15ad Updated seaweedfs from version 4.0.405 to 4.0.407
- 2ffbe15ad Updated teleport-kube-agent from version 18.6.2 to 18.6.3
- 2ffbe15ad Updated traefik from version 38.0.1 to 38.0.2

### Features
- ae840535f feat(friendica): Add Friendica helm chart v1.0.0 with latest image
- ccc1439c3 feat: add opendesk version 1.11.2
- 1e4e48ccb feat: Add Lemmy helm chart with CNPG support
- 9bf1626b7 feat: Add Funkwhale helm chart with CNPG and Redis operator support
- 9d1f63d49 feat:- Add alerts for slurmjob, slurm node failure and pending jobs for long time

### Bug Fixes
- 7eebee3bd fix: handled more edge cases in kubeaid helm chart script
- a8414980b fix links for backup and recovery docs
- b831e921f fix: opendesk build script and ignore opendesk helmfiles yamllint
- 13aa5cbff fix(odoo): disable bundled postgresql subchart to prevent unwanted StatefulSet
- 818e06d43 fixed readme links and addressed comments
- fd83b372c fix lint

### Configuration Changes
- ee2d1630d chore: update global group interval for alertmanager alerts
- 4f627942d chore: add o2 troubleshooting guide
- de464eee7 chore: add flexible configuration of queue config for prometheus

### Other Changes
- f3d261369 doc: fix kube config secret generation in gitea/gitlab runner
- 4a3bbcd3c Removed the grafana ingressroute since we will now use ingress directly and updated the grafana root_url
- 0170069ee Upgraded odoo logical backup image
- f5e75d0d6 added the postgresql-logical-backup for mastodon , pixelfed , peertube , erpnext
- 13bb2c6d0 docs(odoo): Add Recovery/Troubleshooting section to Readme
- 1a836bcff doc: remove extra space between ordered list item in docs/development/ci-cd-setup.md
- 82fbfa4bb update kube prometheus doc with link to example yaml for enabling admin api for prometheus
- 0841e1bcb trivial grammatical fix
- b041a8cba Addressed comments for why kubeaid section
- ae6106e66 Added air gapped writeup
- 61998dd48 renamed operations tips file
- 9cd6140fe Add prometheus config
- 8c14301bb Added helm umbrella patterns
- 49f6b4d11 Add gitops drift detection
- d7edbb8d4 update technical features doc addressing comments
- c03522df3 Added mermaid diagram for kubeaid
- 03240878a Updated refs to Obmondo, camelCase for KubeAid, restructure docs
- 0f5e8b811 Removed redundant docs and blog posts
- 60bdd2b03 Updated package URLs, refs to files, moved aws private link setup to ops
- 6ba14b56b Fix renewal period for barman self signed certs
- be4018c4e Add ed25519 vs rsa key note
- fb578745b Fix mermaid diag, add what commands exit for kubeaid
- 1a9607701 Add tip for saving general yaml file
- ae017da51 Install with tar gz and update installation script with ref to new naming convention
- 0c1aa334a Update installation script with ref to new naming convention
- ae97afa75 Adjust Odoo pgsql logical backup template for the newer image
- a9779af06 Changed cleanup file name to basic-operations
- 9e330b73b Worked upon changes requested - prerequisites doc
- 1f2e5acc9 Worked upon changes requested - preconfiguration doc
- 37cdc1ea8 Worked upon changes requested - installation doc
- cbd6fec12 Worked on changes requested
- 00734ca37 Added mermaid diag for what gets deleted with the cluster delete commands
- 542bff199 Added mermaid diag for repo structure overview
- aee150af8 Added mermaid diag for post config dir structure
- b70b32d61 Added mermaid diag for bootstrap architecture
- 003c02b1b Added mermaid diag for kubeaid features
- f4e9db764 Added explanation as notes in cluster deletion
- 1130e463f Updated the pre-requisite section with deployment architecture and sys requirements
- 4a91f5937 Added ssh key generation instructions, link to appropriate URL
- 84cbfcaf1 Restructure docs getting started and provider-agnostic docs
- 9e9fe3567 Updated refs according to review comments
- 7ab0946e6 Added installation instructions for all hosting providers
- d7d9e9c13 Added pre-requisites doc

## KubeAid Release Version 22.0.0

### Major Version Upgrades
- 7668fab2c Updated traefik from version 37.4.0 to 38.0.1

### Minor Version Upgrades
- 7668fab2c Updated argo-cd from version 9.1.6 to 9.2.4
- 7668fab2c Updated aws-ebs-csi-driver from version 2.53.0 to 2.54.1
- 7668fab2c Updated aws-efs-csi-driver from version 3.2.6 to 3.3.0
- 7668fab2c Updated hcloud-cloud-controller-manager from version 1.28.0 to 1.29.0
- 7668fab2c Updated cloudnative-pg from version 0.26.1 to 0.27.0
- 7668fab2c Updated cluster-autoscaler from version 9.53.0 to 9.54.0
- 7668fab2c Updated gitlab-runner from version 0.83.3 to 0.84.1
- 7668fab2c Updated ingress-nginx from version 4.12.2 to 4.14.1
- 7668fab2c Updated metal3 from version 0.12.9 to 0.13.0
- 7668fab2c Updated opencost from version 2.4.1 to 2.5.1
- 7668fab2c Updated opensearch from version 3.3.2 to 3.4.0
- 7668fab2c Updated opensearch-dashboards from version 3.3.0 to 3.4.0
- 7668fab2c Updated opentelemetry-operator from version 0.99.2 to 0.102.0
- 7668fab2c Updated opentelemetry-collector from version 0.140.1 to 0.142.2
- 7668fab2c Updated postgres-operator from version 1.14.0 to 1.15.1
- 7668fab2c Updated sealed-secrets from version 2.17.9 to 2.18.0
- 7668fab2c Updated sonarqube from version 2025.5.0 to 2025.6.1
- 7668fab2c Updated teleport-cluster from version 18.5.0 to 18.6.2
- 7668fab2c Updated teleport-kube-agent from version 18.5.0 to 18.6.2
- 7668fab2c Updated velero from version 11.2.0 to 11.3.2

### Patch Version Upgrades
- 7668fab2c Updated argocd-image-updater from version 1.0.1 to 1.0.4
- 7668fab2c Updated cloud-provider-azure from version 1.34.2 to 1.34.3
- 7668fab2c Updated cert-manager from version v1.19.1 to v1.19.2
- 7668fab2c Updated cilium from version 1.18.4 to 1.18.5
- 7668fab2c Updated erpnext from version 8.0.0 to 8.0.13
- 7668fab2c Updated fluent-bit from version 0.54.0 to 0.54.1
- 7668fab2c Updated graylog from version 3.0.8 to 3.0.10
- 7668fab2c Updated harbor from version 1.18.0 to 1.18.1
- 7668fab2c Updated keda from version 2.18.1 to 2.18.3
- 7668fab2c Updated mariadb-operator from version 25.10.2 to 25.10.3
- 7668fab2c Updated mattermost-team-edition from version 6.6.88 to 6.6.89
- 7668fab2c Updated reloader from version 2.2.5 to 2.2.7
- 7668fab2c Updated rook-ceph from version v1.18.4 to v1.18.8
- 7668fab2c Updated seaweedfs from version 4.0.401 to 4.0.405
- 7668fab2c Updated trust-manager from version v0.20.2 to v0.20.3
- 7668fab2c Updated tigera-operator from version v3.31.2 to v3.31.3

### Features
- db517617d feat: add sealed-secrets support with cpng backup for openobserve
- a0cc8dae3 feat: Update Odoo chart defaults for Odoo 19
- 6f50ab527 feat: add product and certname labels to all alerts
- 6afd6abbe feat(cnpg): adding the plugin-barman-cloud subchart
- f3f1a2cbf feat: add Kyverno policies for Harbor proxy cache management
- 2aeea136b feat(pixelfed): add KubeAid integration templates and default values
- 13e0bfc81 feat(pixelfed): add Pixelfed helm chart with patched upstream v0.23.0

### Bug Fixes
- 7f14afc30 fix: release script can handle individual helm chart addition/updation commits as well and some sanity check
- 3e97956bd fix: yamllint in pixelfed helm chart.yaml
- 0f0c2d495 fix: handle the helm update script to match correct helm chart name in the cache file, grep was missing the end character
- 4c117f8d7 fix: added correct support for new helm chart, update a specific helm chart and update all the helm chart
- a9d30343a fix(rbac): add pods list permission for prometheus-k8s service account
- 49b317c0d fix: removed the extra character that was getting added in the helm cache file
- ffa99f599 fix: handle the duplicate entry in the .helm_version_last_update
- 8677d592f fix: build script to generate proper helmfile template for each opendesk app
- 348ee89b3 fix: lint fix
- acfc1feb9 fix: helm repo update script bugs
- fff49a79a fix: update the logical backup template to accommodate o2 changes
- 156cc7c26 fix: increase the remote write timeout and decrease the max sample rate to reduce load on promtheus
- da5dc6ab0 fix: add specific k8s service discovery with role endpointSlice
- a3d7b47e9 fix: bitnami for openobserve
- d655d862d fix: added all the netbird image tag to 60.8
- 1d580713d fix: updated netbird image tag
- 0937e7cf3 fix(qa/keycloakx): removing requirement of unnecessary azure credentials
- 2b03ab03d fix: update the g10k cron configs to only use g10k and remove dependency from the rsync
- 0f8bfb8ce fix: handle the empty securityContext in openvox
- 43db942dc fix: converge g10k commands under single arg
- 52a561699 fix: update g10k job to run it in /tmp directory and then rsync on the actual path
- 026a4bb02 fix: added fsGroupChangePolicy on puppetserver deployment as well
- a57a01339 fix: the updatestrategy, where it can end up with multiattach error
- d6669112d fix: mount the eyaml on puppetserver
- aa7f87ad2 fix: speed up volume mount on pvc which has more file, like g10k code

### Configuration Changes
- cf01cf32b chore: update helm charts to v21.1.0
- ae53e55f6 chore: add keycloak user guide in netbird guide
- 864d6ac55 chore: update netbird docs with client setup
- 237c5057f chore(lint): yaml .gitea/workflows/helm-update.yaml

### Other Changes
- f32a607b7 Revert "fix(rbac): add pods list permission for prometheus-k8s service account"
- 5eed0ccb5 docs: remove setup guide link and placeholder section as per review
- d0386f9c4 add opendesk coturn helm chart
- 8ec2e23c8 add flag to create and add new chart
- 5807787f4 Doc: Cmd line to test Prometheus rules using promtool
- 9f8c77279 Fix VeleroUnsuccessfulBackup falsely triggering on mondays and at random for 6hrly
- 852966121 docs: add Harbor registry guide content
- bed7feb9d docs: add guides structure and reorganize access token docs
- bf441ce91 Added the alert for slurm node being down
- 6fb32bb72 Added a backup and restore guide for Odoo
- d068fe7a2 Consolidated cloud provider docs under hosting subsections
- ae9028ef9 Fixed encyption value set up in relate helm chart
- 85eff46e4 add restore and backup procedure for relate
- d9851405f Added fileStore support in mattermost helm
- 63c2ba0e5 Added relevant sections under development subsection
- e1249b1b0 Restructured docs in the operations and monitoring sub folders
- 26b02172f Retrigger CI
- ed8814fd5 Fix: Hardcoded mariadb config to make imagePullSecrets optional for private registry
- 2d3983a1b docs: update README as per review comments
- d1342e3f7 docs: update README
- ef339f0ea docs: update README
- 4de528c05 docs: update README
- 0fe244eeb Remove system namespace from prometheus scrape
- c1ee6f88f Updated the autosign script logic
- a23325126 doc(bare-metal): adding pre-requisites for each server
- 7127e8a5b add skip module in deployment https://gitea.obmondo.com/EnableIT/a0hu8x41ng/issues/113:

## KubeAid Release Version 21.0.0

### Major Version Upgrades
- 44217e3b3 Updated argocd-image-updater from version 1.0.1 to 1.0.1
- 44217e3b3 Updated erpnext from version 8.0.0 to 8.0.0
- 44217e3b3 Updated matomo from version 11.0.0 to 11.0.0

### Minor Version Upgrades
- 44217e3b3 Updated argo-cd from version 9.1.6 to 9.1.6
- 44217e3b3 Updated aws-ebs-csi-driver from version 2.53.0 to 2.53.0
- 44217e3b3 Updated hcloud-cloud-controller-manager from version 1.28.0 to 1.28.0
- 44217e3b3 Updated cluster-autoscaler from version 9.53.0 to 9.53.0
- 44217e3b3 Updated crossplane from version 2.1.3 to 2.1.3
- 44217e3b3 Updated gatekeeper from version 3.21.0 to 3.21.0
- 44217e3b3 Updated gitlab-runner from version 0.83.3 to 0.83.3
- 44217e3b3 Updated grafana-operator from version v5.20.0 to v5.20.0
- 44217e3b3 Updated haproxy from version 1.27.0 to 1.27.0
- 44217e3b3 Updated kubernetes-dashboard from version 7.14.0 to 7.14.0
- 44217e3b3 Updated kyverno from version 3.6.1 to 3.6.1
- 44217e3b3 Updated localpv-provisioner from version 4.5.0-develop to 4.5.0-develop
- 44217e3b3 Updated opentelemetry-operator from version 0.99.2 to 0.99.2
- 44217e3b3 Updated opentelemetry-collector from version 0.140.1 to 0.140.1
- 44217e3b3 Updated redis-operator from version 0.22.2 to 0.22.2
- 44217e3b3 Updated snapshot-controller from version 4.2.0 to 4.2.0
- 44217e3b3 Updated step-certificates from version 1.29.0 to 1.29.0
- 44217e3b3 Updated strimzi-kafka-operator from version 0.49.1 to 0.49.1
- 44217e3b3 Updated teleport-cluster from version 18.5.0 to 18.5.0
- 44217e3b3 Updated teleport-kube-agent from version 18.5.0 to 18.5.0
- 44217e3b3 Updated traefik from version 37.4.0 to 37.4.0
- 44217e3b3 Updated velero from version 11.2.0 to 11.2.0
- 44217e3b3 Updated zfs-localpv from version 2.9.0 to 2.9.0

### Patch Version Upgrades
- 44217e3b3 Updated aws-efs-csi-driver from version 3.2.6 to 3.2.6
- 44217e3b3 Updated azuredisk-csi-driver from version 1.33.7 to 1.33.7
- 44217e3b3 Updated cloud-provider-azure from version 1.34.2 to 1.34.2
- 44217e3b3 Updated cilium from version 1.18.4 to 1.18.4
- 44217e3b3 Updated cluster-api-operator from version 0.24.1 to 0.24.1
- 44217e3b3 Updated graylog from version 3.0.8 to 3.0.8
- 44217e3b3 Updated hcloud-csi from version 2.18.3 to 2.18.3
- 44217e3b3 Updated keda from version 2.18.1 to 2.18.1
- 44217e3b3 Updated keycloakx from version 7.1.5 to 7.1.5
- 44217e3b3 Updated loki-stack from version 2.10.3 to 2.10.3
- 44217e3b3 Updated mariadb-operator from version 25.10.2 to 25.10.2
- 44217e3b3 Updated mattermost-team-edition from version 6.6.88 to 6.6.88
- 44217e3b3 Updated metal3 from version 0.12.9 to 0.12.9
- 44217e3b3 Updated kubernetes-operator from version 0.1.15 to 0.1.15
- 44217e3b3 Updated opencost from version 2.4.1 to 2.4.1
- 44217e3b3 Updated opensearch from version 3.3.2 to 3.3.2
- 44217e3b3 Updated reloader from version 2.2.5 to 2.2.5
- 44217e3b3 Updated rook-ceph from version v1.18.4 to v1.18.8
- 44217e3b3 Updated rook-ceph-cluster from version v1.18.8 to v1.18.8
- 44217e3b3 Updated sealed-secrets from version 2.17.9 to 2.17.9
- 44217e3b3 Updated seaweedfs from version 4.0.401 to 4.0.401
- 44217e3b3 Updated step-issuer from version 1.9.11 to 1.9.11
- 44217e3b3 Updated autocert from version 1.20.5 to 1.20.5
- 44217e3b3 Updated tigera-operator from version v3.31.2 to v3.31.2

### Features
- 633f904c2 feat: add changelog and release not via git commit in release script
- 52085f5ab feat: add changelog.md changes via git commit in release script
- eea77b0e1 feat: removed commented lines in the release script
- 1ef621001 feat: script fix
- fc5649134 feat: the helm repo update script is much faster on re-run and removed old function with better handling and go-release can read the commit and add it in release notes as well.
- cf6f9182f feat: added gorelease setup

### Bug Fixes
- f9af16217 fix: changelog and gorelease config and workflow fix: removed release section from gorelease, since we have our own release note feat: added CI to run on schedule on Sunday
- 2be7ad6d9 fix(cert-manager): remove cached readme.md file
- 346d91596 fix: add the version file in git, so it can be tracked
- 1965b5318 fix: the helm repo update script to get correct version
- b5b74a01f fix: removed unwanted git-push workflow

### Configuration Changes
- bcacb5320 chore(doc): changelog removed, which was added by the script while testing
- 44217e3b3 chore: update helm charts to v21.0.0
- d47555a7e chore(ci): removed some obsolete workflow and fixed some
- 9be977f0c chore: added a echo statement for jsonnetfmt ci check script, to know that it worked fine
- a364b9eef chore: helm-diff, we cant compare with kubeaid-config directly from here
- 0eba80fd0 chore: delete old .gitlab-ci
- acf987300 chore: we never want to uninstall the argocd
- 30c2e6205 chore: deleted generate-puppet-hiera.sh since its not used anymore
- 3b35e8e0c chore: static script for internal usecase

## 20.1.2
### Features
- [`4e23594a81ea25d125ac0cd56ebee84f17998b7e`](../../commit/4e23594a81ea25d125ac0cd56ebee84f17998b7e) Add support for adding extra ports
- [`95222a31d6d5814b5603c8e8bff802fd8bed1c36`](../../commit/95222a31d6d5814b5603c8e8bff802fd8bed1c36) feat: Add Mastodon Helm chart
- [`a171cd469544fffe023e880ee7c733cc631a89f1`](../../commit/a171cd469544fffe023e880ee7c733cc631a89f1) feat: g10k puppet/openvox code support added
- [`285bdc712fb6bccc1b002566c1f4eab9d7204ac8`](../../commit/285bdc712fb6bccc1b002566c1f4eab9d7204ac8) feat: g10k hiera support
- [`65da6ad7b2a53b882ed1485561f6d734006da7c4`](../../commit/65da6ad7b2a53b882ed1485561f6d734006da7c4) Add standalone Redis support for Mastodon
- [`3f1c05353346f323b8cc0be1640f41314406d616`](../../commit/3f1c05353346f323b8cc0be1640f41314406d616) implemeted redis-mode
- [`362ed16db29f225673534e218e024c76054c9be6`](../../commit/362ed16db29f225673534e218e024c76054c9be6) mastodon: Consolidate Redis config with mode option
- [`8b006109f8148174aed509d6cd5a28b9d20b071c`](../../commit/8b006109f8148174aed509d6cd5a28b9d20b071c) Support CAPI clusters with different folder and cluster names

### Fixes
- [`174588109c4fcaae893e08720efd132b3dda70ef`](../../commit/174588109c4fcaae893e08720efd132b3dda70ef) Add: out of shared memory case
- [`caa524960d4aa06721dd883a2c8e6895c7028403`](../../commit/caa524960d4aa06721dd883a2c8e6895c7028403) fix(keycloakx): creating ObjectStore and BackupSchedule resources only when backups are enabled
- [`85bece48c8f1ab09a8b18bb7e051046f460bc6a8`](../../commit/85bece48c8f1ab09a8b18bb7e051046f460bc6a8) fix: Hardcoded AWS_ACCESS_KEY_ID  and mount from Kubernetes Secret
- [`dfbea0aaab6541e3499eea4e8a1c021df1c56450`](../../commit/dfbea0aaab6541e3499eea4e8a1c021df1c56450) fix(rook-ceph): remove null cpu limits from resource configurations to comply with Kubernetes standards
- [`d6ef0fc4658164583fe439d3e3cb660d73a8ae76`](../../commit/d6ef0fc4658164583fe439d3e3cb660d73a8ae76) fix: yamllint
- [`497845b9d18fbffe7856b4a9ca987fb15815383c`](../../commit/497845b9d18fbffe7856b4a9ca987fb15815383c) fix: identation issue for code setup in openvox/g10k
- [`84901d64a7b72f39a53e4c7ebe0dd14629380ebe`](../../commit/84901d64a7b72f39a53e4c7ebe0dd14629380ebe) fix: removed the https setup in g10k, since it does not support netrc
- [`5d7708e0b0c22574f9cc1827d34c3a80f306e564`](../../commit/5d7708e0b0c22574f9cc1827d34c3a80f306e564) fix: dont add r10k configmap and secret, if r10k is disabled
- [`633f4bb370bf5f2a78a2cf08dfac519b4ccc07aa`](../../commit/633f4bb370bf5f2a78a2cf08dfac519b4ccc07aa) Remove legacy redisCluster section from Mastodon - not needed here

### Docs
- [`9961e7bcd1fd267a1855109b8eaaa56736fb391e`](../../commit/9961e7bcd1fd267a1855109b8eaaa56736fb391e) feat: add certificate issuer configuration documentation and example templates for cert-manager
- [`b9cc8928a6d891b934c1742efbe9ffcbea670a9d`](../../commit/b9cc8928a6d891b934c1742efbe9ffcbea670a9d) Added docs for rebooting a kubernetes node
- [`86c67bca9f3e6e1547e54c1a7be66ca8ada45852`](../../commit/86c67bca9f3e6e1547e54c1a7be66ca8ada45852) Improved guide of redis-operator helm chart
- [`8c33bf5b15ce0f9b4b90e295abf8f8509325ad7e`](../../commit/8c33bf5b15ce0f9b4b90e295abf8f8509325ad7e) feat: unbound var resolved and improved docs
- [`1198f6e77116767c62d7cd7be0f6c4112ae8e9b0`](../../commit/1198f6e77116767c62d7cd7be0f6c4112ae8e9b0) WIP: improving argocd keycloak docs..
- [`638bb44ebb672e19ea7acd7472779d7258a8aa58`](../../commit/638bb44ebb672e19ea7acd7472779d7258a8aa58) add note  on kubeaid-argocd-apps.sh script usage

## 20.1.1
### Fixes
- [`fa2628f34235afc67392f8b9d0a5ca11462d7a76`](../../commit/fa2628f34235afc67392f8b9d0a5ca11462d7a76) fix(capi-cluster/hetzner): disabling Hetzner network for HCloud servers | upgrading ClusterAPI component versions
- [`60e412b6fe0bc767484cffe95d6dd56d2863b60b`](../../commit/60e412b6fe0bc767484cffe95d6dd56d2863b60b) fix(capi-cluster/hetzner): Cilium installation command in postKubeadm section

## 20.1.0
### Minor Version Upgrades
- Updated traefik from version 37.1.2 to 37.2.0
- Updated tigera-operator from version v3.30.4 to v3.31.0
- Updated prometheus-adapter from version 5.1.0 to 5.2.0
- Updated opentelemetry-collector from version 0.137.0 to 0.138.0
- Updated opentelemetry-operator from version 0.97.1 to 0.98.0
- Updated opencost from version 2.3.2 to 2.4.0
- Updated mariadb-operator from version 25.8.4 to 25.10.1
- Updated argocd-image-updater from version 0.13.0 to 0.14.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 18.2.7 to 18.2.10
- Updated teleport-cluster from version 18.2.7 to 18.2.10
- Updated seaweedfs from version 4.0.393 to 4.0.399
- Updated rook-ceph-cluster from version v1.18.4 to v1.18.5
- Added rook-ceph from version v1.18.4 to v1.18.4
- Updated opensearch from version 3.3.0 to 3.3.1
- Updated metal3 from version 0.12.7 to 0.12.8
- Updated graylog from version 3.0.1 to 3.0.3
- Updated erpnext from version 7.0.246 to 7.0.247
- Updated cluster-autoscaler from version 9.52.0 to 9.52.1
- Updated cloudnative-pg from version 0.26.0 to 0.26.1
- Updated cilium from version 1.18.2 to 1.18.3
- Updated argo-cd from version 9.0.3 to 9.0.5

### Improvements
- [`813aa6ef`](../../commit/813aa6ef) Add seaweedfs to Kubeaid
- [`fc2defaa`](../../commit/fc2defaa) add support for Adding Cpu and Mem resources for mattermost
- [`b7e9570d`](../../commit/b7e9570d) docs: add instructions for restoring Mattermost DB and updating DB connection string in version 10.11.4
- [`54edbbcd`](../../commit/54edbbcd) add restore scripts for mongodb and postgres logical backups and update readme in cnpg and mongodb operators
- [`ba85c47a`](../../commit/ba85c47a) add persistence in alertmanager https://gitea.obmondo.com/EnableIT/KubeAid/issues/989

## 20.0.0
### Major Version Upgrades
- Updated argo-cd from version 8.6.1 to 9.0.3

### Minor Version Upgrades
- Updated opentelemetry-collector from version 0.136.1 to 0.137.0
- Updated opensearch-dashboards from version 3.2.2 to 3.3.0
- Updated opensearch from version 3.2.1 to 3.3.0
- Updated gitlab-runner from version 0.81.0 to 0.82.0
- Updated cluster-autoscaler from version 9.51.0 to 9.52.0

### Patch Version Upgrades
- Updated velero from version 11.1.0 to 11.1.1
- Updated tigera-operator from version v3.30.3 to v3.30.4
- Updated trust-manager from version v0.20.1 to v0.20.2
- Updated snapshot-controller from version 4.1.0 to 4.1.1
- Added rook-ceph from version v1.18.4 to v1.18.4
- Updated mattermost-team-edition from version 6.6.84 to 6.6.85
- Updated erpnext from version 7.0.244 to 7.0.246
- Updated cert-manager from version v1.19.0 to v1.19.1

### Improvements
- [`6a9c904a`](../../commit/6a9c904a) fixing odoo image
- [`b73121f6`](../../commit/b73121f6) changing ignore to ignore_mountpoint
- [`2a44addd`](../../commit/2a44addd) Updated the disk alert to ignore mountpoints for which we don't want the alert for
- [`936a1f6d`](../../commit/936a1f6d) Add tls support fixed error in logical backup

## 19.1.0
### Minor Version Upgrades
- Updated velero from version 11.0.0 to 11.1.0
- Updated rook-ceph from version v1.17.2 to v1.18.4
- Updated cluster-autoscaler from version 9.50.1 to 9.51.0
- Updated aws-ebs-csi-driver from version 2.50.1 to 2.51.0

### Patch Version Upgrades
- Updated trust-manager from version v0.20.0 to v0.20.1
- Updated opencost from version 2.3.1 to 2.3.2
- Updated erpnext from version 7.0.243 to 7.0.244
- Updated argo-cd from version 8.6.0 to 8.6.1

### Improvements
- [`aeb7c435`](../../commit/aeb7c435) fix: run r10k as a diff pod, if r10k dies, puppet client would fail to connect to puppetserver, since liveness is broken
- [`cc9de2dc`](../../commit/cc9de2dc) adding container image with helm installed
- [`45b06a17`](../../commit/45b06a17) lint fix
- [`f2ab8247`](../../commit/f2ab8247) kept only one monday workflow
- [`f2e15c9d`](../../commit/f2e15c9d) Enable matternelle domain

## 19.0.0
### Major Version Upgrades
- Updated velero from version 10.1.3 to 11.0.0

### Minor Version Upgrades
- Updated strimzi-kafka-operator from version 0.47.0 to 0.48.0
- Updated trust-manager from version v0.19.0 to v0.20.0
- Updated sonarqube from version 2025.4.2 to 2025.5.0
- Updated prometheus-smartctl-exporter from version 0.15.4 to 0.16.0
- Updated opentelemetry-collector from version 0.134.0 to 0.136.1
- Updated opentelemetry-operator from version 0.95.1 to 0.97.1
- Updated opencost from version 2.2.7 to 2.3.1
- Updated keda from version 2.17.2 to 2.18.0
- Updated hcloud-csi from version 2.17.0 to 2.18.0
- Updated haproxy from version 1.24.0 to 1.26.1
- Updated gitea from version 12.3.0 to 12.4.0
- Updated fluent-bit from version 0.53.0 to 0.54.0
- Updated external-dns from version 1.18.0 to 1.19.0
- Updated cluster-api-operator from version 0.23.0 to 0.24.0
- Updated cert-manager from version v1.18.2 to v1.19.0
- Updated hcloud-cloud-controller-manager from version 1.26.0 to 1.27.0
- Updated argocd-image-updater from version 0.12.3 to 0.13.0
- Updated argo-cd from version 8.5.10 to 8.6.0

### Patch Version Upgrades
- Updated traefik from version 37.1.1 to 37.1.2
- Updated teleport-kube-agent from version 18.2.2 to 18.2.7
- Updated teleport-cluster from version 18.2.2 to 18.2.7
- Updated sealed-secrets from version 2.17.1 to 2.17.7
- Updated rook-ceph-cluster from version v1.18.2 to v1.18.4
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated keycloakx from version 7.1.3 to 7.1.4
- Updated graylog from version 3.0.0 to 3.0.1
- Updated erpnext from version 7.0.234 to 7.0.243
- Updated aws-cloud-controller-manager from version 0.0.9 to 0.0.10
- Updated aws-efs-csi-driver from version 3.2.3 to 3.2.4
- Added puppetserver from version 10.0.0 to 10.0.0

## 18.0.0
### Major Version Upgrades
- Updated graylog from version 2.4.1 to 3.0.0

### Minor Version Upgrades
- Updated opentelemetry-collector from version 0.133.0 to 0.134.0
- Updated metal3 from version 0.11.6 to 0.12.7
- Updated harbor from version 1.17.2 to 1.18.0
- Updated gitlab-runner from version 0.80.1 to 0.81.0
- Updated gitea from version 12.2.0 to 12.3.0
- Updated cloud-provider-azure from version 1.33.3 to 1.34.1
- Updated argo-cd from version 8.3.7 to 8.5.3

### Patch Version Upgrades
- Updated velero from version 10.1.2 to 10.1.3
- Updated teleport-kube-agent from version 18.2.1 to 18.2.2
- Updated teleport-cluster from version 18.2.1 to 18.2.2
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated opentelemetry-operator from version 0.95.0 to 0.95.1
- Updated mattermost-team-edition from version 6.6.83 to 6.6.84
- Updated mariadb-operator from version 25.8.3 to 25.8.4
- Updated kyverno from version 3.5.1 to 3.5.2
- Updated erpnext from version 7.0.232 to 7.0.234
- Updated cilium from version 1.18.1 to 1.18.2
- Updated aws-efs-csi-driver from version 3.2.2 to 3.2.3

### Improvements
- [`b613073a`](../../commit/b613073a) update readme
- [`bc4dcbaf`](../../commit/bc4dcbaf) feat: added kube-prom v0.16.0 with a release fix
- [`8a45ab17`](../../commit/8a45ab17) Updated the opendesk so its handled the same way as Kube promethues
- [`9f59c891`](../../commit/9f59c891) fix: handle the kube-prom strict v0.13.0 check gracefully using equality operator
- [`eb20d70f`](../../commit/eb20d70f) fix: Add 10-minute delay to domain status alerts
- [`730d01e3`](../../commit/730d01e3) feat: Added support for ruleNamespaceSelector in common template
- [`3078f816`](../../commit/3078f816) Split Grafana dashboards into per-dashboard ConfigMaps https://gitea.obmondo.com/EnableIT/KubeAid/issues/901
- [`263a8584`](../../commit/263a8584) feat: rabbitmq mixin is coming from a diff upstream repo for v0.13.0, so lets handle that accordingly

## 17.2.0
### Minor Version Upgrades
- Updated traefik from version 37.0.0 to 37.1.1
- Updated teleport-kube-agent from version 18.1.6 to 18.2.1
- Updated teleport-cluster from version 18.1.6 to 18.2.1
- Updated opentelemetry-collector from version 0.131.0 to 0.133.0
- Updated opentelemetry-operator from version 0.93.0 to 0.95.0
- Updated graylog from version 2.3.17 to 2.4.1
- Updated fluent-bit from version 0.52.0 to 0.53.0

### Patch Version Upgrades
- Updated velero from version 10.1.0 to 10.1.2
- Updated rook-ceph-cluster from version v1.18.0 to v1.18.2
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated reloader from version 2.2.2 to 2.2.3
- Updated opensearch-dashboards from version 3.2.1 to 3.2.2
- Updated opencost from version 2.2.4 to 2.2.7
- Updated gitlab-runner from version 0.80.0 to 0.80.1
- Updated gatekeeper from version 3.20.0 to 3.20.1
- Updated erpnext from version 7.0.230 to 7.0.232
- Updated argo-cd from version 8.3.0 to 8.3.7
- Added external-dns from version 1.18.0 to 1.18.0
- Added external-dns from version 1.8.0 to 1.8.0

### Improvements
- [`704be0b5`](../../commit/704be0b5) updating docs acc. to kubeaid cli and removing old procedures
- [`123cd7c9`](../../commit/123cd7c9) Add docs on monitoringPasscode in Sonarqube
- [`0d630359`](../../commit/0d630359) set pgsql to 14 to maintain compatibility
- [`8008b2d8`](../../commit/8008b2d8) chore: add external ip handling for tcp and dup services for netbird setup
- [`8ad0fd1d`](../../commit/8ad0fd1d) chore: add steps for multi platform container images
- [`b77475fb`](../../commit/b77475fb) chore: format the readme to address lint issues
- [`429c53f8`](../../commit/429c53f8) chore: remove deprecated image pull secrets configuration
- [`7420741d`](../../commit/7420741d) chore: update obmondo-k8s-agent app version to v1.1.6
- [`9ef4dfcd`](../../commit/9ef4dfcd) removed awk and used more verbose commands now
- [`91149771`](../../commit/91149771) init
- [`29e3784d`](../../commit/29e3784d) feat: added a default env variable for autosign to get the client cert and private key and updated relevant doc as well
- [`6e91d759`](../../commit/6e91d759) docs: moving user guide for KubeAid CLI here
- [`e9bdc204`](../../commit/e9bdc204) Make TTL for velero weekly schedules configurable
- [`649ed239`](../../commit/649ed239) Added the promethues rule for gitlab runner alert
- [`35add591`](../../commit/35add591) Added the alerts for gitlab runners failing
- [`d435ff36`](../../commit/d435ff36) Updated the readme to explain the variables
- [`b0552b25`](../../commit/b0552b25) Added the examples for the templates
- [`c1a5d045`](../../commit/c1a5d045) Added the templates for secrets required by metal3 for server provisioning
- [`d76f3b09`](../../commit/d76f3b09) fixup! fix: updated puppetserver helm chart, based on custom fixes, which is present in Obmondo git repo, and respective PR has been raised already
- [`c76f751a`](../../commit/c76f751a) chore: removed unwanted postgres chart from puppetserver, since we are using cnpg postgres operator to setup postgres
- [`3ac2fe4c`](../../commit/3ac2fe4c) fix: updated puppetserver helm chart, based on custom fixes, which is present in Obmondo git repo, and respective PR has been raised already
- [`28749b7d`](../../commit/28749b7d) chore: added a comment to NOTE, that upstream puppetserver helm chart is quite behind and PR are not getting merged, so will wait for the upstream guys to do that, for now manual changes from the Obmondo git repos to get going
- [`6da5826f`](../../commit/6da5826f) feat: updated metal3 documentation
- [`73da157a`](../../commit/73da157a) doc: updated readme, on how to create the tlsoption and add puppetca cert, so we can verify the client request coming on to puppetdb
- [`e0668838`](../../commit/e0668838) feat: added support to setup ingressroute without customerid
- [`1caf77ea`](../../commit/1caf77ea) Remove misplaced alert rule from LinuxAid
- [`89f93149`](../../commit/89f93149) feat: set netbird default chart values with examples and setup ingress
- [`9abd4322`](../../commit/9abd4322) add coturn realm support
- [`edd656e0`](../../commit/edd656e0) fix name of coturn pgsql backup
- [`7e9b0de4`](../../commit/7e9b0de4) fix lint
- [`f1cf3134`](../../commit/f1cf3134) Add coturn pgqsl and logical backup Fix minor issues in helm chart
- [`34ea4c01`](../../commit/34ea4c01) Improve readme of netbird and add examples
- [`87de6fd0`](../../commit/87de6fd0) chore(sealed-secrets): having an enabled field in the backup section
- [`2113f858`](../../commit/2113f858) fix(cluster-autoscaler): disabling clusterAPIScaleToZeroSupport by default
- [`11c41d41`](../../commit/11c41d41) Move external-dns helm chart to k8s repo from bitnami
- [`078245e1`](../../commit/078245e1) fix(velero): override daily schedule TTL to prevent snapshot accumulation

## 17.1.0
### Minor Version Upgrades
- Updated redmine from version 33.0.6 to 34.0.0
- Updated rook-ceph-cluster from version v1.17.7 to v1.18.0
- Updated opentelemetry-collector from version 0.130.2 to 0.131.0
- Updated opentelemetry-operator from version 0.84.1 to 0.93.0
- Updated opensearch-dashboards from version 3.1.0 to 3.2.1
- Updated opensearch from version 3.1.0 to 3.2.1
- Updated gitlab-runner from version 0.79.1 to 0.80.0
- Updated gitea from version 12.1.3 to 12.2.0
- Updated fluent-bit from version 0.51.0 to 0.52.0
- Updated cluster-api-operator from version 0.22.0 to 0.23.0
- Updated cloudnative-pg from version 0.25.0 to 0.26.0
- Updated aws-ebs-csi-driver from version 2.47.0 to 2.48.0
- Updated argo-cd from version 8.2.5 to 8.3.0

### Patch Version Upgrades
- Updated tigera-operator from version v3.30.2 to v3.30.3
- Updated teleport-kube-agent from version 18.1.4 to 18.1.6
- Updated teleport-cluster from version 18.1.4 to 18.1.6
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated reloader from version 2.2.0 to 2.2.2
- Updated rabbitmq-cluster-operator from version 4.4.31 to 4.4.34
- Updated opencost from version 2.2.0 to 2.2.4
- Updated oncall from version 1.16.4 to 1.16.5
- Updated metallb from version 6.4.21 to 6.4.22
- Updated mattermost-team-edition from version 6.6.81 to 6.6.83
- Updated kyverno from version 3.5.0 to 3.5.1
- Updated keycloakx from version 7.1.1 to 7.1.3
- Updated graylog from version 2.3.16 to 2.3.17
- Updated external-dns from version 9.0.2 to 9.0.3
- Updated erpnext from version 7.0.227 to 7.0.230
- Updated cluster-autoscaler from version 9.50.0 to 9.50.1
- Updated cilium from version 1.18.0 to 1.18.1
- Updated azuredisk-csi-driver from version 1.33.2 to 1.33.4
- Updated aws-efs-csi-driver from version 3.2.1 to 3.2.2

### Improvements
- [`3cfe6bc5`](../../commit/3cfe6bc5) Adding sftpgo helm chart default values in KubeAid.
- [`3c3ca94e`](../../commit/3c3ca94e) feat: add support for configuring Prometheus replicas fix: set replicas to 1 to conditionally disable PodDisruptionBudget creation
- [`524e9c99`](../../commit/524e9c99) doc: updated readme with correct steps and added an example values file as well
- [`5132d839`](../../commit/5132d839) fix: max duration of the cert issued via step-issuer
- [`dab5ff28`](../../commit/dab5ff28) fix: removed default cluster-issuer, since it can be any other cluster issuer
- [`9d5cd235`](../../commit/9d5cd235) fix: changed the trust.namespace for trust manager
- [`015f071a`](../../commit/015f071a) fix: removed namespace from the step-ca-bundle, since that is not supported by the crd
- [`cbe6c066`](../../commit/cbe6c066) fix: yaml structure for step-ca values file, so it takes correct input
- [`cac8d8dc`](../../commit/cac8d8dc) fix: removed extra chart, which got added in the kubeaid, and its already present in the kubeaid
- [`df2cbf13`](../../commit/df2cbf13) fix: url for stepclusterissuer and get namespace from release.name in step-ca, so one can deploy in a diff namespace
- [`28c82829`](../../commit/28c82829) fix: updated act_runner image to current latest to 0.2.12 again in the kubeaid values file
- [`7625cabf`](../../commit/7625cabf) fix: updated act_runner image to current latest to 0.2.12
- [`9e1222ea`](../../commit/9e1222ea) feat: Added Guide for Odoo
- [`dc82208a`](../../commit/dc82208a) chore(netbird-dashboard): bump version to v2.17.0
- [`8e7c4913`](../../commit/8e7c4913) fix: shell check fix for git branch command in the helm-repo update
- [`642ec92e`](../../commit/642ec92e) fix: readme.yaml should have been readme.md
- [`e2ee70f1`](../../commit/e2ee70f1) feat: added some sane default for autocert, in step-ca doc: Updated readme with some instruction to setup the step-ca feat: added support for bundle and stepclusterissuer from values file feat: added a posthook to create cert with 90 days expiry fix: enabled secret target for trust manager, since cert-manager can inject the root ca in the pod, and it can read only secret
- [`c6ecc167`](../../commit/c6ecc167) feat: added autocert helm chart
- [`150fa8ea`](../../commit/150fa8ea) feat: enabled autocert helm chart and added a WIP readme
- [`df4c5aa3`](../../commit/df4c5aa3) feat: added bundle object for default step-ca setup, and didnt templatized it yet
- [`67329969`](../../commit/67329969) feat: added trust-manager helm chart as dependency, since its required when one is doing a step-ca setup on their cluster
- [`544bf24c`](../../commit/544bf24c) feat: added step-ca readme, and support for step-ca in cert-manager
- [`c9878e8f`](../../commit/c9878e8f) chore(netbird): add installation tips to replicate the same configs
- [`80802c78`](../../commit/80802c78) chore(netbird): add installation tips to replicate the same configs
- [`6a15f6d7`](../../commit/6a15f6d7) adding redirect-to-www middleware in Odoo
- [`b09fedda`](../../commit/b09fedda) adding sftpgo helm chart to kubeaid
- [`93925b76`](../../commit/93925b76) feat: added step-certificates helm chart
- [`9f94ab63`](../../commit/9f94ab63) fix: helm update script when there is more then 1 dependencies and added stepca-certificates in the chart.yaml for step-ca helm chart
- [`1526cb17`](../../commit/1526cb17) Allow adding labels to keycloak zalando postgres db

## 17.0.0
### Major Version Upgrades
- Updated whoami from version 5.3.0 to 6.0.0
- Updated traefik from version 36.3.0 to 37.0.0
- Updated prometheus-adapter from version 4.14.1 to 5.1.0
- Updated mariadb-operator from version 0.38.1 to 25.8.3
- Updated external-dns from version 8.9.2 to 9.0.2
- Updated crossplane from version 1.20.0 to 2.0.2

### Minor Version Upgrades
- Updated velero from version 10.0.9 to 10.1.0
- Updated teleport-kube-agent from version 18.0.0 to 18.1.4
- Updated teleport-cluster from version 18.0.0 to 18.1.4
- Updated strimzi-kafka-operator from version 0.46.1 to 0.47.0
- Updated sonarqube from version 2025.3.1 to 2025.4.2
- Updated reloader from version 2.1.5 to 2.2.0
- Updated opentelemetry-collector from version 0.127.3 to 0.130.2
- Updated opencost from version 2.1.6 to 2.2.0
- Updated metrics-server from version 3.12.2 to 3.13.0
- Updated kyverno from version 3.4.4 to 3.5.0
- Updated keycloakx from version 7.0.1 to 7.1.1
- Updated hcloud-csi from version 2.16.0 to 2.17.0
- Updated gitlab-runner from version 0.78.1 to 0.79.1
- Updated gatekeeper from version 3.19.2 to 3.20.0
- Updated fluent-bit from version 0.50.0 to 0.51.0
- Updated cluster-autoscaler from version 9.48.0 to 9.50.0
- Updated cluster-api-operator from version 0.21.0 to 0.22.0
- Updated cloudnative-pg from version 0.24.0 to 0.25.0
- Updated cilium from version 1.17.5 to 1.18.0
- Updated cerebro from version 2.1.0 to 2.2.0
- Updated aws-ebs-csi-driver from version 2.45.1 to 2.47.0
- Updated argo-cd from version 8.1.3 to 8.2.5

### Patch Version Upgrades
- Updated prometheus-smartctl-exporter from version 0.15.3 to 0.15.4
- Updated rook-ceph-cluster from version v1.17.6 to v1.17.7
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated redmine from version 33.0.2 to 33.0.6
- Updated rabbitmq-cluster-operator from version 4.4.25 to 4.4.31
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Updated oncall from version 1.16.1 to 1.16.4
- Updated odoo from version 28.2.7 to 28.2.10
- Updated kubernetes-operator from version 0.1.10 to 0.1.13
- Updated metallb from version 6.4.19 to 6.4.21
- Updated mattermost-team-edition from version 6.6.80 to 6.6.81
- Updated mattermost-operator from version 1.0.3 to 1.0.4
- Updated harbor from version 1.17.1 to 1.17.2
- Updated graylog from version 2.3.15 to 2.3.16
- Updated gitea from version 12.1.1 to 12.1.3
- Updated erpnext from version 7.0.214 to 7.0.227
- Updated cloud-provider-azure from version 1.33.0 to 1.33.3
- Updated aws-cloud-controller-manager from version 0.0.8 to 0.0.9
- Updated aws-efs-csi-driver from version 3.2.0 to 3.2.1

### Patch Version Upgrades
- Updated prometheus-smartctl-exporter from version 0.15.3 to 0.15.4
- Updated rook-ceph-cluster from version v1.17.6 to v1.17.7
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated redmine from version 33.0.2 to 33.0.6
- Updated rabbitmq-cluster-operator from version 4.4.25 to 4.4.31
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Updated oncall from version 1.16.1 to 1.16.4
- Updated odoo from version 28.2.7 to 28.2.10
- Updated kubernetes-operator from version 0.1.10 to 0.1.13
- Updated metallb from version 6.4.19 to 6.4.21
- Updated mattermost-team-edition from version 6.6.80 to 6.6.81
- Updated mattermost-operator from version 1.0.3 to 1.0.4
- Updated harbor from version 1.17.1 to 1.17.2
- Updated graylog from version 2.3.15 to 2.3.16
- Updated gitea from version 12.1.1 to 12.1.3
- Updated erpnext from version 7.0.214 to 7.0.227
- Updated cloud-provider-azure from version 1.33.0 to 1.33.3
- Updated aws-cloud-controller-manager from version 0.0.8 to 0.0.9
- Updated aws-efs-csi-driver from version 3.2.0 to 3.2.1
- Added step-issuer from version 1.9.9 to 1.9.9

### Improvements
- [`48b2d915`](../../commit/48b2d915) feat: added step-ca/step-issuer helm chart
- [`0ef5efd7`](../../commit/0ef5efd7) feat: improved doc, readme for harbor and removed ceph tool cpu limit
- [`f03eb805`](../../commit/f03eb805) feat: cert-manager clusterissue with self-signed support
- [`b3c094da`](../../commit/b3c094da) doc: updated readme on how to generate eyaml keys and added it as a secret
- [`12d28114`](../../commit/12d28114) fix: image for puppet-agent exporter is pointing to a public repo now
- [`0dcb3f96`](../../commit/0dcb3f96) fix: removed storageclass which is specific for a user, so users can give their own storageclass for puppetserver
- [`f3551d84`](../../commit/f3551d84) fix: HostSNI for puppetserver role, so it picks up the entire fqdns
- [`3fdd367a`](../../commit/3fdd367a) feat: added sane defaults for puppetserver helm chart
- [`88aeeff2`](../../commit/88aeeff2) Updated the README
- [`d8639d36`](../../commit/d8639d36) chore: disable chart openobserve updates since it doesn't have support for client secrets
- [`ecc562ed`](../../commit/ecc562ed) Added the wiki and script to build opendesk
- [`f101927e`](../../commit/f101927e) update
- [`ff271eaa`](../../commit/ff271eaa) update
- [`6208f8db`](../../commit/6208f8db) update
- [`70826070`](../../commit/70826070) update
- [`9f8b5a52`](../../commit/9f8b5a52) enable
- [`2c95a55c`](../../commit/2c95a55c) templatized mattermost
- [`c4311342`](../../commit/c4311342) Add mattermost-operator
- [`40126ed8`](../../commit/40126ed8) feat(kube-prometheus): add remoteWrite config
- [`de03e52a`](../../commit/de03e52a) update node count alert interval to 24hr
- [`012b83fe`](../../commit/012b83fe) update: obmondo-k8s-agent image tag to v1.1.5
- [`c5168b0e`](../../commit/c5168b0e) feat(obmondo-k8s-agent): update image tag to v1.1.4
- [`18d88e76`](../../commit/18d88e76) added postgres cluster
- [`828fb058`](../../commit/828fb058) enabled postgres
- [`1d557b29`](../../commit/1d557b29) added postgres
- [`d726b682`](../../commit/d726b682) feat(obmondo-k8s-agent): update image tag to v1.1.2
- [`a37cb3e7`](../../commit/a37cb3e7) chore(helm-charts): add and update few default values in argo-cd and sealed-secrets apps
- [`ef474927`](../../commit/ef474927) feat : using subchart pattern for CrossPlane Helm charts | Making infrastructure provisioning using CrossPlane idempotent | Updating default version for Kubernetes and ClusterAPI components
- [`246dd2dd`](../../commit/246dd2dd) feat(kubeaid-bootstrap-script/crossplane) : removing the crossplane-provider Helm chart | adding crossplane, crossplane-providers-and-functions and crossplane-compositions Helm charts for creating Azure workload-identity and disaster-recovery infrastructure
- [`093c8727`](../../commit/093c8727) updating the ccm-azure KubeAid Helm chart
- [`50d5a2a7`](../../commit/50d5a2a7) feat: update image tag to v1.1.0 and add additional environment variables
- [`4cd8324c`](../../commit/4cd8324c) fix: correct image tag format in values.yaml
- [`2e6839b1`](../../commit/2e6839b1) chore: update obmondo-k8s-agent image tag to 1.1.0
- [`c334ffaf`](../../commit/c334ffaf) Updated opendesk version
- [`531ce269`](../../commit/531ce269) increasing postgres instance to 2 for Odoo
- [`b46098a1`](../../commit/b46098a1) fix: switch redis replication to singleton redis
- [`5c3e8f07`](../../commit/5c3e8f07) chore: add documentation describing the extra configurations needed with secrets for setting up harbor
- [`b9b0737d`](../../commit/b9b0737d) feat: add init container for harbor job service while checking for harbor core service
- [`629b13f1`](../../commit/629b13f1) fix: clean the redis replication configurations
- [`7352540f`](../../commit/7352540f) feat: add init containers for postgres and redis
- [`fe98d590`](../../commit/fe98d590) fix: change redis cluster to redis replication
- [`c1c87d89`](../../commit/c1c87d89) fix: update the redis service to attach with it
- [`7002b5d9`](../../commit/7002b5d9) fix: enable external redis cluster for harbor
- [`82f28104`](../../commit/82f28104) feat: add redis cluster to harbor
- [`d2625f09`](../../commit/d2625f09) fix: change the harbor logical backup retention time type to string

## 16.1.0
### Minor Version Upgrades
- Updated cluster-autoscaler from version 9.47.0 to 9.48.0

### Patch Version Upgrades
- Updated velero from version 10.0.8 to 10.0.9
- Updated rook-ceph-cluster from version v1.17.5 to v1.17.6
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated redmine from version 33.0.0 to 33.0.2
- Updated rabbitmq-cluster-operator from version 4.4.24 to 4.4.25
- Updated opentelemetry-collector from version 0.127.2 to 0.127.3
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated metallb from version 6.4.18 to 6.4.19
- Updated external-dns from version 8.9.1 to 8.9.2
- Updated erpnext from version 7.0.211 to 7.0.214
- Updated azuredisk-csi-driver from version 1.33.1 to 1.33.2
- Updated argo-cd from version 8.1.2 to 8.1.3

### Improvements
- [`f5ba05b2`](../../commit/f5ba05b2) chore: bump the hetzner failover script tag version to v1.1.0
- [`8114c1d7`](../../commit/8114c1d7) fix: changed the image.tag and fixed env

## 16.0.1
### Improvements
- [`b0aed250`](../../commit/b0aed250) chore(kube-prometheus) : we don't need the ceph mixin by default
- [`05157ec5`](../../commit/05157ec5) fix(capi-cluster/hetzner) : explicitly specifying the routing device to Cilium, only in case of HCloud control-plane
- [`74c8eb01`](../../commit/74c8eb01) chore(capi-cluster/hetzner) : not having cloud-provider labels in control-plane nodes (for now)

## 16.0.0
### Major Version Upgrades
- Updated teleport-kube-agent from version 17.5.2 to 18.0.0
- Updated teleport-cluster from version 17.5.2 to 18.0.0

### Minor Version Upgrades
- Updated traefik from version 36.2.0 to 36.3.0
- Updated fluent-bit from version 0.49.1 to 0.50.0
- Updated external-dns from version 8.8.6 to 8.9.1
- Updated cluster-autoscaler from version 9.46.6 to 9.47.0
- Updated cluster-api-operator from version 0.20.0 to 0.21.0
- Updated hcloud-cloud-controller-manager from version 1.25.1 to 1.26.0
- Updated aws-efs-csi-driver from version 3.1.9 to 3.2.0

### Patch Version Upgrades
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated reloader from version 2.1.4 to 2.1.5
- Updated rabbitmq-cluster-operator from version 4.4.23 to 4.4.24
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated opencost from version 2.1.5 to 2.1.6
- Updated odoo from version 28.2.6 to 28.2.7
- Updated graylog from version 2.3.14 to 2.3.15
- Updated gitlab-runner from version 0.78.0 to 0.78.1
- Updated gitea from version 12.1.0 to 12.1.1
- Updated erpnext from version 7.0.208 to 7.0.211
- Updated cert-manager from version v1.18.1 to v1.18.2
- Updated argo-cd from version 8.1.1 to 8.1.2

## 15.1.0
### Improvements
- [`df63ed62`](../../commit/df63ed62) feat(kyverno) : adding the Kyverno Helm chart

## 15.0.0
### Major Version Upgrades
- Updated redmine from version 32.2.6 to 33.0.0

### Minor Version Upgrades
- Updated opensearch-operator from version 2.7.0 to 2.8.0
- Updated opensearch-dashboards from version 3.0.0 to 3.1.0
- Updated opensearch from version 3.0.0 to 3.1.0
- Updated netbird from version 1.6.1 to 1.8.0

### Patch Version Upgrades
- Updated velero from version 10.0.7 to 10.0.8
- Updated strimzi-kafka-operator from version 0.46.0 to 0.46.1
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated rabbitmq-cluster-operator from version 4.4.22 to 4.4.23
- Updated opentelemetry-collector from version 0.127.1 to 0.127.2
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Added coturn from version 9.1.0 to 9.1.0

### Improvements
- [`e7cff8b3`](../../commit/e7cff8b3) feat(capi-cluster/hetzner) : ClusterAPI managed cloud-provider label for each node
- [`c5b55eb3`](../../commit/c5b55eb3) fix(capi-cluster/hetzner) : using specific routing device names for Cilium
- [`ad4ad3dd`](../../commit/ad4ad3dd) fix(capi-cluster/hetzner) : considering Hetzner Bare Metal node-groups if mode is set to bare-metal or hybrid
- [`9f61874e`](../../commit/9f61874e) fix(capi-cluster/hetzner) : not specifying Hetzner Bare Metal SSH Key in sshKeys.hcloud section
- [`fb890f5f`](../../commit/fb890f5f) add release procedure doc
- [`295411af`](../../commit/295411af) fix(capi-cluster/hetzner) : increasing node-startup timeout in MachineHealthChecks | Removing remediation | installing socat and mtr at last
- [`2053a670`](../../commit/2053a670) fix(capi-cluster/hetzner) : in second or remainig master nodes, creating and applying the netplan config after 'kubeadm join' execution
- [`323a513c`](../../commit/323a513c) chore: added coturn helm chart
- [`c3694db5`](../../commit/c3694db5) chore: netbird helm chart update
- [`5125d06b`](../../commit/5125d06b) create kubeaid-security-config chart and add resource quota template
- [`1ce224ad`](../../commit/1ce224ad) chore(capi-cluster/hetzner) : Upgrade ContainerD and ClusterAPI components version
- [`815b0471`](../../commit/815b0471) fix(capi-cluster/hetzner) : KubeadmConfigTemplates for Hetzner Bare Metal worker nodes
- [`7b04245e`](../../commit/7b04245e) fix(capi-cluster/hetzner) : removing netplan config for worker nodes
- [`6c4892ec`](../../commit/6c4892ec) feat(helm): add pg_dump toggle and backup CronJob config
- [`c5243bc9`](../../commit/c5243bc9) fix(capi-cluster/hetzner) : increasing time-out to 30m for each Hetzner bare-metal machine

## 14.2.0
### Minor Version Upgrades
- Updated traefik from version 36.1.0 to 36.2.0
- Updated snapshot-controller from version 4.0.2 to 4.1.0
- Updated opentelemetry-collector from version 0.126.0 to 0.127.1
- Updated hcloud-csi from version 2.15.0 to 2.16.0
- Updated gitlab-runner from version 0.77.3 to 0.78.0
- Updated aws-ebs-csi-driver from version 2.44.0 to 2.45.1

### Patch Version Upgrades
- Updated velero from version 10.0.5 to 10.0.7
- Updated tigera-operator from version v3.30.1 to v3.30.2
- Updated sonarqube from version 2025.3.0 to 2025.3.1
- Updated prometheus-smartctl-exporter from version 0.15.1 to 0.15.3
- Updated rook-ceph-cluster from version v1.17.4 to v1.17.5
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated reloader from version 2.1.3 to 2.1.4
- Updated redmine from version 32.2.5 to 32.2.6
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated metal3 from version 0.11.5 to 0.11.6
- Updated mattermost-team-edition from version 6.6.79 to 6.6.80
- Updated keda from version 2.17.1 to 2.17.2
- Updated graylog from version 2.3.11 to 2.3.14
- Updated gatekeeper from version 3.19.1 to 3.19.2
- Updated erpnext from version 7.0.205 to 7.0.208
- Updated cilium from version 1.17.4 to 1.17.5
- Updated cert-manager from version v1.18.0 to v1.18.1
- Updated argocd-image-updater from version 0.12.2 to 0.12.3
- Updated argo-cd from version 8.1.0 to 8.1.1

### Improvements
- [`a5838310`](../../commit/a5838310) fix(cert-manager) : indentation issue in ClusterIssuer template
- [`38d05a64`](../../commit/38d05a64) chore(capi-cluster/hetzner) : not installing Hetzner Failover Script using CAPI's postKubeadm hook
- [`cc7115a8`](../../commit/cc7115a8) chore: remove redundant logical backup provider env var
- [`3ac189b8`](../../commit/3ac189b8) fix(capi-cluster/hetzner) : deploying hetzner-robot to kube-system namespace
- [`299a4ebb`](../../commit/299a4ebb) bug fixes
- [`84cbafc9`](../../commit/84cbafc9) adding parameter for wiping all disks | adding host selector for each HetznerBareMetalMachineTemplate | restructuring | bug fixes
- [`b8fa20ce`](../../commit/b8fa20ce) fixes(capi-cluster/hetzner)

## 14.1.0
### Minor Version Upgrades
- Updated traefik from version 36.0.0 to 36.1.0
- Updated gitea from version 12.0.0 to 12.1.0
- Updated argo-cd from version 8.0.17 to 8.1.0

### Patch Version Upgrades
- Updated velero from version 10.0.4 to 10.0.5
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated rabbitmq-cluster-operator from version 4.4.21 to 4.4.22
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.75 to 0.14.78
- Updated metallb from version 6.4.16 to 6.4.18
- Updated mattermost-team-edition from version 6.6.78 to 6.6.79
- Updated gitlab-runner from version 0.77.2 to 0.77.3
- Updated external-dns from version 8.8.4 to 8.8.6
- Updated erpnext from version 7.0.204 to 7.0.205
- Updated workload-identity-webhook from version 1.5.0 to 1.5.1

### Improvements
- [`2a48ca74`](../../commit/2a48ca74) fix: added chart.yaml for netbird, after migrating to official helm chart
- [`af00f780`](../../commit/af00f780) chore: migrated netbird to official helm chart
- [`f385dadf`](../../commit/f385dadf) fix: kube-prom, the rabbitmq-mixin lib from the correct upstream

## 14.0.0
### Major Version Upgrades
- Updated traefik from version 35.4.0 to 36.0.0

### Minor Version Upgrades
- Updated teleport-kube-agent from version 17.4.10 to 17.5.2
- Updated teleport-cluster from version 17.4.10 to 17.5.2
- Updated localpv-provisioner from version 4.3.0-prerelease to 4.4.0-develop
- Updated hcloud-csi from version 2.14.0 to 2.15.0
- Updated cert-manager from version v1.17.2 to v1.18.0

### Patch Version Upgrades
- Updated velero from version 10.0.1 to 10.0.4
- Updated rook-ceph-cluster from version v1.17.3 to v1.17.4
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated rabbitmq-cluster-operator from version 4.4.15 to 4.4.21
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.73 to 0.14.75
- Updated opencost from version 2.1.3 to 2.1.5
- Updated odoo from version 28.2.4 to 28.2.6
- Updated metallb from version 6.4.13 to 6.4.16
- Updated metal3 from version 0.11.4 to 0.11.5
- Updated graylog from version 2.3.10 to 2.3.11
- Updated fluent-bit from version 0.49.0 to 0.49.1
- Updated external-dns from version 8.8.3 to 8.8.4
- Updated erpnext from version 7.0.201 to 7.0.204
- Updated argo-cd from version 8.0.14 to 8.0.17
- Added localpv-provisioner from version 4.3.0-prerelease to 4.3.0-prerelease

### Improvements
- [`834453b0`](../../commit/834453b0) adding v0.15.0 of kube-prometheus-stack
- [`8430762b`](../../commit/8430762b) fix: renamed the chart to follow the standard partice and added some sane default in values file
- [`678e31b1`](../../commit/678e31b1) feat: added localpv support from openebs helm chart
- [`33109399`](../../commit/33109399) fix: cilium can figure out the k8s service host by itself using a configmap and kubeaid clone should checkout to a latest tag of kubeaid
- [`db36d5b7`](../../commit/db36d5b7) fix: removed the set commands for the cilium setup, since cilium can figure it out by reading the cluster-info configmap, and install the ccm chart based on the mode
- [`4feabfdc`](../../commit/4feabfdc) Added the ingress nginx chart supported by Opendesk
- [`f664df51`](../../commit/f664df51) Added the chartname for ccm-hetzner and cilium
- [`d52afed2`](../../commit/d52afed2) Updated the secret name since thats what bootstrap script creates
- [`defe6695`](../../commit/defe6695) Updated the chart for ccm-hetzner and renamed older ccm-hetzner chart to ccm-hcloud
- [`8ca3168d`](../../commit/8ca3168d) added a default image.tag, since the helm chart is on master(When it was copied from), which is pointing to 5.1.0, for which image is not build yet
- [`21722044`](../../commit/21722044) fix: added missing crds for nginx
- [`b213cd7a`](../../commit/b213cd7a) feat: added nginx-ingress controller in kubeaid, manually
- [`62040801`](../../commit/62040801) fix: hetzner-robot helm chart only if control plane is more then 1 and removed the Archi kubeaid clone
- [`608bc259`](../../commit/608bc259) fix: renamed cluster-api to cluster-api-operator
- [`0c475902`](../../commit/0c475902) added missing coturn helm chart
- [`a3cf7451`](../../commit/a3cf7451) fixed bad Chart.yaml
- [`9dcae2e2`](../../commit/9dcae2e2) feat: added netbid chart for setting up management server
- [`83ccda69`](../../commit/83ccda69) adding support for Hetzner bare-metal

## 13.1.0
### Minor Version Upgrades
- Updated zfs-localpv from version 2.7.1 to 2.8.0
- Updated sonarqube from version 2025.2.0 to 2025.3.0
- Updated opentelemetry-collector from version 0.125.0 to 0.126.0
- Updated kubernetes-dashboard from version 7.12.0 to 7.13.0
- Updated cluster-api-operator from version 0.19.0 to 0.20.0

### Patch Version Upgrades
- Updated tigera-operator from version v3.30.0 to v3.30.1
- Updated rook-ceph-cluster from version v1.17.2 to v1.17.3
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated rabbitmq-cluster-operator from version 4.4.11 to 4.4.15
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated opencost from version 2.1.2 to 2.1.3
- Updated metal3 from version 0.11.3 to 0.11.4
- Updated harbor from version 1.17.0 to 1.17.1
- Updated erpnext from version 7.0.200 to 7.0.201
- Updated azuredisk-csi-driver from version 1.33.0 to 1.33.1
- Updated argocd-image-updater from version 0.12.1 to 0.12.2
- Updated argo-cd from version 8.0.10 to 8.0.14

### Improvements
- [`ed01bde7`](../../commit/ed01bde7) feat: added netbird operator helm chart
- [`1705a6dc`](../../commit/1705a6dc) fix: change blackbox probe static config type from string to array
- [`0db217e8`](../../commit/0db217e8) feat: added opendesk support, with helmfile and apps of apps pattern
- [`f5c60858`](../../commit/f5c60858) adding opensearch-operator helm chart

## 13.0.0
### Major Version Upgrades
- Updated velero from version 9.1.2 to 10.0.1
- Updated gitea from version 11.0.1 to 12.0.0

### Minor Version Upgrades
- Updated traefik from version 35.2.0 to 35.4.0
- Updated opentelemetry-collector from version 0.122.5 to 0.125.0
- Updated hcloud-csi from version 2.13.0 to 2.14.0
- Updated gitlab-runner from version 0.76.1 to 0.77.2
- Updated crossplane from version 1.19.1 to 1.20.0
- Updated cloudnative-pg from version 0.23.2 to 0.24.0
- Updated cloud-provider-azure from version 1.32.4 to 1.33.0
- Updated azuredisk-csi-driver from version 1.32.1 to 1.33.0
- Updated aws-ebs-csi-driver from version 2.43.0 to 2.44.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 17.4.9 to 17.4.10
- Updated teleport-cluster from version 17.4.9 to 17.4.10
- Added rook-ceph from version v1.17.2 to v1.17.2
- Updated redmine from version 32.2.4 to 32.2.5
- Updated rabbitmq-cluster-operator from version 4.4.10 to 4.4.11
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.71 to 0.14.73
- Updated oncall from version 1.16.0 to 1.16.1
- Updated metallb from version 6.4.12 to 6.4.13
- Updated metal3 from version 0.11.1 to 0.11.3
- Updated mattermost-team-edition from version 6.6.76 to 6.6.78
- Updated keda from version 2.17.0 to 2.17.1
- Updated external-dns from version 8.8.2 to 8.8.3
- Updated erpnext from version 7.0.197 to 7.0.200
- Updated cilium from version 1.17.3 to 1.17.4
- Updated hcloud-cloud-controller-manager from version 1.25.0 to 1.25.1
- Updated argo-cd from version 8.0.1 to 8.0.10

### Improvements
- [`7b1d36f4`](../../commit/7b1d36f4) fix(graylog) : disabling opensearch and mongodb | increasing memory request and limit
- [`f54794e6`](../../commit/f54794e6) Update yamllint to skip helm templates
- [`a6d7e26c`](../../commit/a6d7e26c) Add backup and Restore Document
- [`1bdb248e`](../../commit/1bdb248e) doc: updated readme for ciso superuser account recovery
- [`52d03023`](../../commit/52d03023) added a small readme and removed the annotations part from here
- [`08572692`](../../commit/08572692) WIP
- [`c029e53d`](../../commit/c029e53d) WIP
- [`439e6ab7`](../../commit/439e6ab7) WIP
- [`04f05bb2`](../../commit/04f05bb2) WIP: minor change
- [`a566839b`](../../commit/a566839b) WIP: updated ingress
- [`9acbdeec`](../../commit/9acbdeec) WIP: making change in port
- [`d2978306`](../../commit/d2978306) chore: added zfs-localpv as storage class for vuls PV
- [`95e8d0f0`](../../commit/95e8d0f0) fix: changed the PVC mode to RWM
- [`699620ef`](../../commit/699620ef) fix: updated the value file for ciso-assitant based on the new chart
- [`62f7b0c5`](../../commit/62f7b0c5) migrated the ciso helm chart to newer chart, since old one is deprecated
- [`c172adb4`](../../commit/c172adb4) making KubePrometheus build script compatible with MacOS
- [`0698f2e0`](../../commit/0698f2e0) Enable postgres wal backup on mattermost
- [`a63c3845`](../../commit/a63c3845) chore: updated cve-dictionary verision
- [`51edfbee`](../../commit/51edfbee) granting read allowance for resources in storage APIGroup to Cluster AutoScaler
- [`363e6de8`](../../commit/363e6de8) shifting from Syself's to HCloud's CCM Helm chart
- [`3ffe1324`](../../commit/3ffe1324) adding cnpg support to odoo
- [`9f669d9e`](../../commit/9f669d9e) fix(capi-cluster/hetzner)
- [`0a0554e7`](../../commit/0a0554e7) capi-cluster/hetzner subchart streamlining and fixes | adding hcloud-csi-driver chart
- [`9e18088d`](../../commit/9e18088d) adding odoo helm chart
- [`6b90c9b8`](../../commit/6b90c9b8) fix: the sealed secret for alertmanager, needs an empty hash for spec.encryptedData
- [`e853fdb9`](../../commit/e853fdb9) readme on hrms module
- [`75c16733`](../../commit/75c16733) adding hetzner capi templates
- [`efef8e9d`](../../commit/efef8e9d) Ignore exported_certname label while ignoring the blacklist services from the service down alert
- [`404f7599`](../../commit/404f7599) chore(capi-cluster) : updating versions
- [`f9aa5ea6`](../../commit/f9aa5ea6) feat(capi-cluster/azure) : adding option to specify image ID
- [`5076551f`](../../commit/5076551f) added azuredisk-csi-driver Helm chart
- [`3065973a`](../../commit/3065973a) feat: add recommendation to back up prometheus data

## 12.0.0
### Major Version Upgrades
- Updated opensearch-dashboards from version 2.28.0 to 3.0.0
- Updated opensearch from version 2.32.0 to 3.0.0
- Updated argo-cd from version 7.8.27 to 8.0.1

### Minor Version Upgrades
- Updated velero from version 9.0.0 to 9.1.2
- Updated traefik from version 35.0.1 to 35.2.0
- Updated tigera-operator from version v3.29.3 to v3.30.0
- Updated strimzi-kafka-operator from version 0.45.0 to 0.46.0
- Updated prometheus-smartctl-exporter from version 0.13.0 to 0.15.1
- Updated rook-ceph-cluster from version v1.16.0 to v1.17.2
- Updated opencost from version 2.0.2 to 2.1.2
- Updated oncall from version 1.15.6 to 1.16.0
- Updated fluent-bit from version 0.48.10 to 0.49.0
- Updated external-dns from version 8.7.11 to 8.8.2
- Updated cluster-api-operator from version 0.18.1 to 0.19.0
- Updated aws-ebs-csi-driver from version 2.42.0 to 2.43.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 17.4.5 to 17.4.9
- Updated teleport-cluster from version 17.4.5 to 17.4.9
- Updated rook-ceph from version v1.17.0 to v1.17.2
- Updated reloader from version 2.1.1 to 2.1.3
- Updated redmine from version 32.2.2 to 32.2.4
- Updated rabbitmq-cluster-operator from version 4.4.7 to 4.4.10
- Updated opentelemetry-collector from version 0.122.1 to 0.122.5
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.53 to 0.14.71
- Updated metallb from version 6.4.9 to 6.4.12
- Updated metal3 from version 0.11.0 to 0.11.1
- Updated mattermost-team-edition from version 6.6.74 to 6.6.76
- Updated gitlab-runner from version 0.76.0 to 0.76.1
- Updated gatekeeper from version 3.19.0 to 3.19.1
- Updated erpnext from version 7.0.193 to 7.0.197
- Updated cert-manager from version v1.17.1 to v1.17.2
- Updated cloud-provider-azure from version 1.32.3 to 1.32.4
- Updated aws-efs-csi-driver from version 3.1.8 to 3.1.9

### Improvements
- [`df5caa0a`](../../commit/df5caa0a) chore: remove old monitoring stack rules
- [`10df1661`](../../commit/10df1661) chore: remove old opsmondo rules
- [`99727ddc`](../../commit/99727ddc) chore: lint the yaml formatting
- [`e93a0392`](../../commit/e93a0392) fix: reduce repeat_interval to 5m for obmondo route
- [`367ba05d`](../../commit/367ba05d) update tag noble generic build in dockerfile
- [`8ad021e6`](../../commit/8ad021e6) renaming velero alert expressions test file from rules.yaml to tests.yaml
- [`f8e1440f`](../../commit/f8e1440f) fix(keycloakx/backup) : updated keycloakx's postgres logical backup container image
- [`16aef75e`](../../commit/16aef75e) Add Loki stack Helm chart with dependencies and configuration
- [`51d259a3`](../../commit/51d259a3) fix: correct file names
- [`3271b72d`](../../commit/3271b72d) Update postgres wiki
- [`c08cfa44`](../../commit/c08cfa44) feat(capi-cluster/azure) : adding the azure-workload-identity-webhook KubeAid chart
- [`6d3d3879`](../../commit/6d3d3879) feat(capi-cluster/azure) : consuming service account issuer keys from Kubernetes Secret | removing root account password for each node
- [`5a5beacf`](../../commit/5a5beacf) Enable logical backup for harbor
- [`5da4825b`](../../commit/5da4825b) fix: puppetboard worker is increased to 2
- [`a6e61128`](../../commit/a6e61128) fix: added the default image.tag for puppetserver and puppetdb
- [`4a5a455e`](../../commit/4a5a455e) fix: updated puppetboard image.tag to 6.0.1
- [`d336600c`](../../commit/d336600c) feat: added harbor blog and examples
- [`168f7683`](../../commit/168f7683) added improved velero alerts and Prometheus unit tests
- [`6ab3bbb1`](../../commit/6ab3bbb1) feat(alerting/velero) : alerts should be generated when there are no successfull backups / snapshots for a schedule
- [`7ef1ce15`](../../commit/7ef1ce15) feat(velero) : adding VolumeSnapshotClass template
- [`7348ec29`](../../commit/7348ec29) increase memory request and limit for Velero pod
- [`79611254`](../../commit/79611254) feat: moved Harbor DB migration doc to wiki
- [`30244101`](../../commit/30244101) fix HELM_UPSTREAM_CHART_VERSION unbound error when no upstream chart is present
- [`fe405a27`](../../commit/fe405a27) changes done locally to ensure required SANs are there in kafka certificates
- [`ae1790db`](../../commit/ae1790db) migrating harbor database to postgress cnpg
- [`0d228919`](../../commit/0d228919) fix(capi-cluster/azure) : fixed the subchart
- [`631b14a4`](../../commit/631b14a4) capu-cluster/azure chart changes
- [`bd159817`](../../commit/bd159817) Updated Readme
- [`fd542e54`](../../commit/fd542e54) adding metal3 readme, hostupdatepolicy crd, and baremetal-operaor rbac rules

## 11.0.0
### Major Version Upgrades
- Updated velero from version 8.7.1 to 9.0.0
- Updated traefik from version 34.5.0 to 35.0.1

### Minor Version Upgrades
- Updated rook-ceph from version v1.16.6 to v1.17.0
- Updated reloader from version 2.0.0 to 2.1.1
- Updated prometheus-adapter from version 4.13.0 to 4.14.1
- Updated opentelemetry-collector from version 0.120.2 to 0.122.1
- Updated community-operator from version 0.12.1 to 0.13.0
- Updated kubernetes-dashboard from version 7.11.1 to 7.12.0
- Updated keda from version 2.16.1 to 2.17.0
- Updated harbor from version 1.16.2 to 1.17.0
- Updated gitlab-runner from version 0.75.1 to 0.76.0
- Updated gatekeeper from version 3.18.2 to 3.19.0
- Updated aws-ebs-csi-driver from version 2.41.0 to 2.42.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 17.4.2 to 17.4.5
- Updated teleport-cluster from version 17.4.2 to 17.4.5
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated redmine from version 32.2.0 to 32.2.2
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.42 to 0.14.53
- Updated opencost from version 2.0.1 to 2.0.2
- Updated oncall from version 1.15.2 to 1.15.6
- Updated mattermost-team-edition from version 6.6.73 to 6.6.74
- Updated mariadb-operator from version 0.38.0 to 0.38.1
- Updated fluent-bit from version 0.48.9 to 0.48.10
- Updated external-dns from version 8.7.10 to 8.7.11
- Updated erpnext from version 7.0.183 to 7.0.193
- Updated cilium from version 1.17.2 to 1.17.3
- Updated cloud-provider-azure from version 1.32.0 to 1.32.3
- Updated argo-cd from version 7.8.23 to 7.8.27

### Improvements
- [`a02aeefb`](../../commit/a02aeefb) ignore monitoring buildx container
- [`c1a0eee8`](../../commit/c1a0eee8) ignore docker container down alerts for gitea actions task
- [`9211891c`](../../commit/9211891c) feat(capi-cluster/azure) : support provisioning self-managed Azure based Kubernetes cluster using ClusterAPI
- [`cca9be4e`](../../commit/cca9be4e) Add docs for fluent bit DNS issue

## 10.4.0
### Minor Version Upgrades
- Updated redmine from version 32.1.6 to 32.2.0
- Updated metal3 from version 0.10.1 to 0.11.0

### Patch Version Upgrades
- Updated velero from version 8.7.0 to 8.7.1
- Updated teleport-kube-agent from version 17.4.1 to 17.4.2
- Updated teleport-cluster from version 17.4.1 to 17.4.2
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rabbitmq-cluster-operator from version 4.4.6 to 4.4.7
- Updated opentelemetry-collector from version 0.120.0 to 0.120.2
- Added opentelemetry-operator from version 0.84.1 to 0.84.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.40 to 0.14.42
- Updated community-operator from version 0.12.0 to 0.12.1
- Updated metallb from version 6.4.8 to 6.4.9
- Updated external-dns from version 8.7.8 to 8.7.10
- Updated erpnext from version 7.0.182 to 7.0.183
- Updated cluster-api-operator from version 0.18.0 to 0.18.1
- Updated argocd-image-updater from version 0.12.0 to 0.12.1
- Updated argo-cd from version 7.8.15 to 7.8.23

### Improvements
- [`7127e98e`](../../commit/7127e98e) Add steps to setup keycloak with azure ad
- [`50bef534`](../../commit/50bef534) KubeAid release '10.3.0'
- [`28e32acf`](../../commit/28e32acf) Add commit since 10.2.0 tag to CHANGELOG.md
- [`fc1695d7`](../../commit/fc1695d7) feat: added kubeaid-agent user for argocd, so kubeaid-agent can talk to argocd

## 10.3.0
### Minor Version Upgrades
- Updated velero from version 8.5.0 to 8.7.0
- Updated traefik from version 34.4.1 to 34.5.0
- Updated teleport-kube-agent from version 17.3.3 to 17.4.1
- Updated teleport-cluster from version 17.3.3 to 17.4.1
- Updated sonarqube from version 2025.1.1 to 2025.2.0
- Updated opentelemetry-collector from version 0.117.0 to 0.120.0
- Updated opentelemetry-operator from version 0.83.0 to 0.84.1
- Updated opencost from version 1.43.2 to 2.0.1
- Updated metal3 from version 0.9.3 to 0.10.1
- Updated mariadb-operator from version 0.37.1 to 0.38.0
- Updated gitlab-runner from version 0.74.1 to 0.75.1
- Updated cluster-api-operator from version 0.17.1 to 0.18.0

### Patch Version Upgrades
- Updated tigera-operator from version v3.29.2 to v3.29.3
- Updated snapshot-controller from version 4.0.1 to 4.0.2
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rook-ceph from version v1.16.5 to v1.16.6
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.31 to 0.14.40
- Updated gitea from version 11.0.0 to 11.0.1
- Updated external-dns from version 8.7.7 to 8.7.8
- Updated erpnext from version 7.0.176 to 7.0.182
- Updated crossplane from version 1.19.0 to 1.19.1
- Updated cluster-autoscaler from version 9.46.3 to 9.46.6
- Updated aws-efs-csi-driver from version 3.1.7 to 3.1.8
- Updated argo-cd from version 7.8.11 to 7.8.15

### Improvements
- [`165f0ea0`](../../commit/165f0ea0) revert argocd image updater file deletion
- [`9fee0318`](../../commit/9fee0318) fix: changed it to ttyS1 for ironic agent
- [`0a2fa253`](../../commit/0a2fa253) adding metal3 helm chart

## 10.2.0
### Minor Version Upgrades
- Updated whoami from version 5.2.1 to 5.3.0
- Updated opentelemetry-operator from version 0.82.0 to 0.83.0
- Updated aws-ebs-csi-driver from version 2.40.3 to 2.41.0

### Patch Version Upgrades
- Updated sonarqube from version 2025.1.0 to 2025.1.1
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Added opentelemetry-collector from version 0.117.0 to 0.117.0
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated mattermost-team-edition from version 6.6.71 to 6.6.73
- Updated erpnext from version 7.0.175 to 7.0.176
- Updated cluster-autoscaler from version 9.46.2 to 9.46.3
- Updated cluster-api-operator from version 0.17.0 to 0.17.1
- Updated cilium from version 1.17.1 to 1.17.2
- Updated argo-cd from version 7.8.10 to 7.8.11

### Improvements
- [`0e60e5da`](../../commit/0e60e5da) Revert "add for clause for the domain status alert"
- [`a39e6426`](../../commit/a39e6426) add for clause for the domain status alert

## 10.1.0
### Minor Version Upgrades
- Updated velero from version 8.4.0 to 8.5.0
- Updated reloader from version 1.3.0 to 2.0.0
- Updated prometheus-adapter from version 4.11.0 to 4.13.0
- Updated opentelemetry-operator from version 0.81.0 to 0.82.0
- Updated kubernetes-dashboard from version 7.10.5 to 7.11.1

### Patch Version Upgrades
- Updated traefik from version 34.4.0 to 34.4.1
- Updated teleport-kube-agent from version 17.3.0 to 17.3.3
- Updated teleport-cluster from version 17.3.0 to 17.3.3
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rook-ceph from version v1.16.4 to v1.16.5
- Updated redmine from version 32.1.5 to 32.1.6
- Updated rabbitmq-cluster-operator from version 4.4.5 to 4.4.6
- Added opentelemetry-collector from version 0.117.0 to 0.117.0
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated oncall from version 1.15.0 to 1.15.2
- Updated metallb from version 6.4.7 to 6.4.8
- Updated gitlab-runner from version 0.74.0 to 0.74.1
- Updated fluent-bit from version 0.48.8 to 0.48.9
- Updated external-dns from version 8.7.5 to 8.7.7
- Updated erpnext from version 7.0.171 to 7.0.175
- Updated cloudnative-pg from version 0.23.0 to 0.23.2
- Updated aws-ebs-csi-driver from version 2.40.2 to 2.40.3
- Updated argo-cd from version 7.8.7 to 7.8.10

### Improvements
- [`29ddc747`](../../commit/29ddc747) fix(capi-cluster/aws) : user must specify subnet IDs when using an existing VPC
- [`5d41a062`](../../commit/5d41a062) fix: typo bug in jsonnet, which was causing kube build to fail when generating the config file

## 10.0.1
### Improvements
- [`b17fc1c7`](../../commit/b17fc1c7) fix(kube-prometheus) : setting ruleNamespaceSelector to {} instead of null
- [`8b6e0d95`](../../commit/8b6e0d95) fix(kube-prometheus) : check whether vars.prometheus.storage.classname exists or not
- [`fc86d47e`](../../commit/fc86d47e) traefik fix

## 10.0.0
### Major Version Upgrades
- Updated gitea from version 10.6.0 to 11.0.0

### Minor Version Upgrades
- Updated teleport-kube-agent from version 17.2.8 to 17.3.0
- Updated teleport-cluster from version 17.2.8 to 17.3.0
- Updated opentelemetry-operator from version 0.80.1 to 0.81.0
- Updated opensearch-dashboards from version 2.27.1 to 2.28.0
- Updated opensearch from version 2.31.0 to 2.32.0
- Updated cluster-api-operator from version 0.16.0 to 0.17.0

### Patch Version Upgrades
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated redmine from version 32.1.4 to 32.1.5
- Added opentelemetry-collector from version 0.117.0 to 0.117.0
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.20 to 0.14.31
- Updated kubernetes-dashboard from version 7.10.4 to 7.10.5
- Updated fluent-bit from version 0.48.6 to 0.48.8
- Updated erpnext from version 7.0.168 to 7.0.171
- Updated cluster-autoscaler from version 9.46.0 to 9.46.2
- Updated aws-ebs-csi-driver from version 2.40.0 to 2.40.2
- Updated argo-cd from version 7.8.5 to 7.8.7

### Improvements
- [`d97438bd`](../../commit/d97438bd) fix(blogs/capi/aws) : fixed a command
- [`cba37bb2`](../../commit/cba37bb2) chore(docs) : updating part 1 of the KubeAid demonstration blog series for AWS

## 9.4.0
### Minor Version Upgrades
- Updated velero from version 8.3.0 to 8.4.0
- Updated traefik from version 34.3.0 to 34.4.0
- Updated reloader from version 1.2.1 to 1.3.0
- Updated opentelemetry-collector from version 0.116.0 to 0.117.0
- Updated oncall from version 1.14.4 to 1.15.0
- Updated haproxy from version 1.23.0 to 1.24.0
- Updated gitlab-runner from version 0.73.3 to 0.74.0
- Updated aws-ebs-csi-driver from version 2.39.3 to 2.40.0

### Patch Version Upgrades
- Updated yetibot from version 1.0.107 to 1.0.108
- Updated teleport-kube-agent from version 17.2.7 to 17.2.8
- Updated teleport-cluster from version 17.2.7 to 17.2.8
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rook-ceph from version v1.16.3 to v1.16.4
- Added opentelemetry-operator from version 0.80.1 to 0.80.1
- Updated opensearch-dashboards from version 2.27.0 to 2.27.1
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated metallb from version 6.4.6 to 6.4.7
- Updated mattermost-team-edition from version 6.6.70 to 6.6.71
- Updated external-dns from version 8.7.4 to 8.7.5
- Updated erpnext from version 7.0.166 to 7.0.168
- Updated aws-efs-csi-driver from version 3.1.6 to 3.1.7
- Updated argo-cd from version 7.8.2 to 7.8.5

### Improvements
- [`9d02ac9c`](../../commit/9d02ac9c) feat(capi-cluster/aws) : added support to specify additional users, each with corresponding SSH public key | fixed scale from 0 support and node cordoning issue
- [`87c451b1`](../../commit/87c451b1) fix(sealed-secrets) : using correct container image and service-account name
- [`69127059`](../../commit/69127059) updates from my KubeAid fork
- [`a0541c48`](../../commit/a0541c48) (fix/hetzner-failover) : Adjust envs
- [`f108bb10`](../../commit/f108bb10) (fix/capi-cluster) : default values file structure | using super-admin.conf as the kubeconfig file

## 9.3.0
### Minor Version Upgrades
- Updated opentelemetry-operator from version 0.79.0 to 0.80.1
- Updated opensearch-dashboards from version 2.26.0 to 2.27.0
- Updated opensearch from version 2.30.1 to 2.31.0
- Updated crossplane from version 1.18.2 to 1.19.0

### Patch Version Upgrades
- Updated zfs-localpv from version 2.7.0 to 2.7.1
- Updated teleport-kube-agent from version 17.2.6 to 17.2.7
- Updated teleport-cluster from version 17.2.6 to 17.2.7
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rabbitmq-cluster-operator from version 4.4.3 to 4.4.5
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated oncall from version 1.14.3 to 1.14.4
- Updated metallb from version 6.4.5 to 6.4.6
- Updated fluent-bit from version 0.48.5 to 0.48.6
- Updated erpnext from version 7.0.164 to 7.0.166
- Updated cilium from version 1.17.0 to 1.17.1
- Updated cert-manager from version v1.17.0 to v1.17.1
- Updated aws-efs-csi-driver from version 3.1.5 to 3.1.6

## 9.2.0
### Minor Version Upgrades
- Updated zfs-localpv from version 2.6.2 to 2.7.0
- Updated traefik from version 34.2.0 to 34.3.0
- Updated opentelemetry-collector from version 0.115.0 to 0.116.0
- Updated cilium from version 1.16.6 to 1.17.0
- Updated cert-manager from version v1.16.3 to v1.17.0
- Updated argo-cd from version 7.7.22 to 7.8.2

### Patch Version Upgrades
- Updated tigera-operator from version v3.29.1 to v3.29.2
- Updated teleport-kube-agent from version 17.2.3 to 17.2.6
- Updated teleport-cluster from version 17.2.3 to 17.2.6
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rook-ceph from version v1.16.2 to v1.16.3
- Added openobserve-collector from version 0.3.22 to 0.3.22
- Updated openobserve from version 0.14.18 to 0.14.20
- Updated oncall from version 1.14.1 to 1.14.3
- Updated metallb from version 6.4.4 to 6.4.5
- Updated kubernetes-dashboard from version 7.10.3 to 7.10.4
- Updated keycloakx from version 7.0.0 to 7.0.1
- Updated external-dns from version 8.7.3 to 8.7.4
- Updated erpnext from version 7.0.161 to 7.0.164

### Improvements
- [`86cc10d7`](../../commit/86cc10d7) [Fix] Install promtool v2.55.0
- [`d4371a7d`](../../commit/d4371a7d) add nvme percentage used rule in smartmon
- [`d6aa5338`](../../commit/d6aa5338) fix kubeaid build script: remove unknown monitoring mixin

## 9.1.0
### Minor Version Upgrades
- Updated traefik from version 34.1.0 to 34.2.0
- Updated mariadb-operator from version 0.36.0 to 0.37.1
- Updated keycloakx from version 6.0.0 to 7.0.0
- Updated cluster-api-operator from version 0.15.1 to 0.16.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 17.2.2 to 17.2.3
- Updated teleport-cluster from version 17.2.2 to 17.2.3
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated redmine from version 32.1.2 to 32.1.4
- Updated openobserve-collector from version 0.3.21 to 0.3.22
- Updated openobserve from version 0.14.7 to 0.14.18
- Updated kubernetes-dashboard from version 7.10.1 to 7.10.3
- Updated erpnext from version 7.0.160 to 7.0.161
- Updated aws-ebs-csi-driver from version 2.39.1 to 2.39.3
- Updated argo-cd from version 7.7.17 to 7.7.22

### Improvements
- [`3f135670`](../../commit/3f135670) fix: changed the resources to have a decent load working with it
- [`fc45ac62`](../../commit/fc45ac62) Add opentelemetry collector chart
- [`91d9d45f`](../../commit/91d9d45f) feat(capi-cluster/aws) : accepting existing VPC ID from the user
- [`bb2de70e`](../../commit/bb2de70e) use postInitApplicationSQL instead of postInitSQL in puppet psql to add extensions
- [`a9ba19cd`](../../commit/a9ba19cd) add postInitSQL key in puppetserver psql to add psql extensions required for puppet 8
- [`1593d7cc`](../../commit/1593d7cc) Move opentelemetry operator outside of openobserve

## 9.0.0
### Major Version Upgrades
- Updated sonarqube from version 10.8.1 to 2025.1.0

### Minor Version Upgrades
- Updated velero from version 8.2.0 to 8.3.0
- Updated traefik from version 33.2.1 to 34.1.0
- Updated teleport-kube-agent from version 17.1.5 to 17.2.2
- Updated teleport-cluster from version 17.1.5 to 17.2.2
- Updated opentelemetry-operator from version 0.78.1 to 0.79.0
- Updated gitlab-runner from version 0.72.0 to 0.73.3
- Updated cluster-autoscaler from version 9.45.0 to 9.46.0
- Updated aws-ebs-csi-driver from version 2.38.1 to 2.39.1
- Updated argocd-image-updater from version 0.11.4 to 0.12.0

### Patch Version Upgrades
- Updated whoami from version 5.2.0 to 5.2.1
- Updated snapshot-controller from version 4.0.0 to 4.0.1
- Updated sealed-secrets from version 2.17.0 to 2.17.1
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rook-ceph from version v1.16.1 to v1.16.2
- Updated reloader from version 1.2.0 to 1.2.1
- Updated redmine from version 32.1.1 to 32.1.2
- Updated rabbitmq-cluster-operator from version 4.4.1 to 4.4.3
- Updated opensearch from version 2.30.0 to 2.30.1
- Added openobserve from version 0.14.7 to 0.14.7
- Updated opencost from version 1.43.0 to 1.43.2
- Updated metallb from version 6.4.2 to 6.4.4
- Updated mattermost-team-edition from version 6.6.67 to 6.6.70
- Updated harbor from version 1.16.1 to 1.16.2
- Updated fluent-bit from version 0.48.4 to 0.48.5
- Updated external-dns from version 8.7.1 to 8.7.3
- Updated erpnext from version 7.0.155 to 7.0.160
- Updated cilium from version 1.16.5 to 1.16.6
- Updated cert-manager from version v1.16.2 to v1.16.3
- Updated argo-cd from version 7.7.15 to 7.7.17

### Improvements
- [`85a48265`](../../commit/85a48265) Migrating cnpg in mattermost and updating the logical backup templates.
- [`3a498a67`](../../commit/3a498a67) fix: yamllint fix
- [`54d4431e`](../../commit/54d4431e) feat: split the cronjob, so all the container does not get spawned on a single node
- [`05cb0098`](../../commit/05cb0098) feat: added pvc support
- [`09a33c39`](../../commit/09a33c39) feat: added instruction to download the dbs
- [`9ce10d93`](../../commit/9ce10d93) chore: renamed from cve-dict to vuls-dict
- [`47ab3474`](../../commit/47ab3474) fix: the appversion and correct key to lookup to find the image.tag
- [`b1088620`](../../commit/b1088620) fix: deleted unwanted files from helm chart of cve-dictionary
- [`8075b92c`](../../commit/8075b92c) feat: added vuls-cve and oval db
- [`6d899590`](../../commit/6d899590) Fix project name in jsonnet for ArgoCD kubeaid apps
- [`9d77e0f5`](../../commit/9d77e0f5) fixing probe name for puppetserver
- [`b2db6ed7`](../../commit/b2db6ed7) adding ingress template for ciso-assistant
- [`93444600`](../../commit/93444600) (fix/capi-cluster) : MachineDeployment min-size defaults to 0
- [`df9eeb99`](../../commit/df9eeb99) (feat/capi-cluster) : add ClusterRole and ClusterRoleBinding, to support ClusterAPI scale from zero feature

## 8.1.0
### Minor Version Upgrades
- Updated velero from version 8.1.0 to 8.2.0
- Updated prometheus-smartctl-exporter from version 0.11.0 to 0.13.0
- Updated postgres-operator from version 1.13.0 to 1.14.0
- Updated opensearch-dashboards from version 2.25.0 to 2.26.0
- Updated opensearch from version 2.28.0 to 2.30.0
- Updated opentelemetry-operator from version 0.75.1 to 0.78.1
- Updated opencost from version 1.42.3 to 1.43.0
- Updated oncall from version 1.13.11 to 1.14.1
- Updated keycloakx from version 4.0.0 to 6.0.0
- Updated cluster-autoscaler from version 9.43.2 to 9.45.0
- Updated cloudnative-pg from version 0.22.1 to 0.23.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 17.1.1 to 17.1.5
- Updated teleport-cluster from version 17.1.1 to 17.1.5
- Added rook-ceph-cluster from version v1.16.0 to v1.16.0
- Updated rook-ceph from version v1.16.0 to v1.16.1
- Updated openobserve-collector from version 0.3.18 to 0.3.21
- Added openobserve from version 0.14.7 to 0.14.7
- Updated kubernetes-dashboard from version 7.10.0 to 7.10.1
- Updated keda from version 2.16.0 to 2.16.1
- Updated harbor from version 1.16.0 to 1.16.1
- Updated gatekeeper from version 3.18.1 to 3.18.2
- Updated fluent-bit from version 0.48.3 to 0.48.4
- Updated erpnext from version 7.0.146 to 7.0.155
- Updated aws-efs-csi-driver from version 3.1.4 to 3.1.5
- Updated argocd-image-updater from version 0.11.3 to 0.11.4
- Updated argo-cd from version 7.7.11 to 7.7.15

### Improvements
- [`4241f405`](../../commit/4241f405) (chore/capi-cluster) : minor UX improve by modifying a Helm parameter path
- [`f665ed21`](../../commit/f665ed21) (fix/capi-cluster) : using extraArgs instead of extraEnvs to enable ETCD metrics
- [`3a7a104a`](../../commit/3a7a104a) fix: moving the opsmondo alert into respective git repo
- [`3ca6d588`](../../commit/3ca6d588) fix: watchdog alerts should come from opsmondo helm chart
- [`09df8811`](../../commit/09df8811) (traefik) : enabling ServiceMonitor
- [`bc851e4d`](../../commit/bc851e4d) (capi-cluster) : using cluster-name + control-plane as label selectors in MachineHealthcheck
- [`1f947eef`](../../commit/1f947eef) (cluster-api) : Updating cluster-api-operator subchart to v0.15.1
- [`377a47af`](../../commit/377a47af) Updating container image versions in cluster-api and capi-cluster Helm chart
- [`8d444ae6`](../../commit/8d444ae6) (capi-cluster) : syncing Chart.lock with Chart.yaml
- [`72e80d21`](../../commit/72e80d21) (capi-cluster) : AWS Infrastructure Provider component should run in a master node
- [`4c9661a0`](../../commit/4c9661a0) (capi-cluster) : Helm chart error fixes
- [`a3563a80`](../../commit/a3563a80) (capi-cluster) : Always having ETCD metrics enabled
- [`064f1c48`](../../commit/064f1c48) (feat/capi-cluster) : allowing users to pass : extraArgs and extraVolumes to KubeAPI | files to be added in master nodes
- [`f2deec6e`](../../commit/f2deec6e) Update the README for relate chart Add nginx to relate deployment templated velero schedule's includenamespaces field
- [`452c1edf`](../../commit/452c1edf) adding ciso-assistant in helm charts
- [`bbcca257`](../../commit/bbcca257) fixed all blackbox probes
- [`ffcdb71a`](../../commit/ffcdb71a) remove commit for each helm update
- [`3a5d13af`](../../commit/3a5d13af) update kafka-operator chart, add steps in doc to use go with kafka
- [`4d7095be`](../../commit/4d7095be) adding templates to setup mariadb and redis instance using corresponding operators for erpnext
- [`dfea13b8`](../../commit/dfea13b8) adding erpnext helm chart under kubeaid to enable sales support data collection
- [`dc1641de`](../../commit/dc1641de) add smartmon disk relocated sector alert, move all smartmon alert rules to one file
- [`619be769`](../../commit/619be769) bug fix: mount eyaml secret on /tmp/puppet/configmap/eyaml/keys upstream pr - https://github.com/puppetlabs/puppetserver-helm-chart/pull/239
- [`0e64d89d`](../../commit/0e64d89d) update default volume
- [`86572b42`](../../commit/86572b42) add cnpg backup and ngnix server to serve static files

## 8.0.0
### Major Version Upgrades
- Updated keycloakx from version 3.0.0 to 4.0.0
- Updated ccm-hetzner from version 1.1.15 to 2.0.1

### Minor Version Upgrades
- Updated teleport-kube-agent from version 17.0.5 to 17.1.1
- Updated teleport-cluster from version 17.0.5 to 17.1.1
- Updated strimzi-kafka-operator from version 0.44.0 to 0.45.0
- Updated rook-ceph-cluster from version v1.15.6 to v1.16.0
- Updated rook-ceph from version v1.15.6 to v1.16.0
- Updated opensearch from version 2.27.1 to 2.28.0
- Updated community-operator from version 0.11.0 to 0.12.0
- Updated gitlab-runner from version 0.71.0 to 0.72.0
- Updated cluster-api-operator from version 0.14.0 to 0.15.0

### Patch Version Upgrades
- Updated sonarqube from version 10.8.0 to 10.8.1
- Updated rabbitmq-cluster-operator from version 4.4.0 to 4.4.1
- Added openobserve from version 0.14.7 to 0.14.7
- Updated metallb from version 6.4.1 to 6.4.2
- Updated gatekeeper from version 3.18.0 to 3.18.1
- Updated external-dns from version 8.7.0 to 8.7.1
- Updated crossplane from version 1.18.1 to 1.18.2
- Updated cilium from version 1.16.4 to 1.16.5
- Updated aws-efs-csi-driver from version 3.1.2 to 3.1.4
- Updated argo-cd from version 7.7.10 to 7.7.11

### Improvements
- [`109b8841`](../../commit/109b8841) Fixing hetzner-robot Helm chart
- [`26b6539e`](../../commit/26b6539e) Adding the hetzner-robot KubeAid App
- [`8fb9ab22`](../../commit/8fb9ab22) Updated the docker rules and fixed the test case for docker container status
- [`66d3c0ad`](../../commit/66d3c0ad) update from pg operator from zalando to cncf for relate in kbm
- [`75ecc54e`](../../commit/75ecc54e) Update helm chart update script to handle individual helm update logging properly and fix name change bug

## 7.0.0

### Major Version Upgrades
- Updated snapshot-controller from version 3.0.6 to 4.0.0
- Updated keycloakx from version 2.6.0 to 3.0.0

### Minor Version Upgrades
- Updated traefik from version 33.1.0 to 33.2.1
- Updated redmine from version 32.0.1 to 32.1.1
- Updated rabbitmq-cluster-operator from version 4.3.29 to 4.4.0
- Updated metallb from version 6.3.16 to 6.4.1
- Updated gatekeeper from version 3.17.1 to 3.18.0
- Updated external-dns from version 8.6.1 to 8.7.0
- Updated aws-ebs-csi-driver from version 2.37.0 to 2.38.1
- Updated strimzi-kafka-operator from version 0.38.0 to 0.44.0

### Patch Version Upgrades
- Updated teleport-kube-agent from version 17.0.4 to 17.0.5
- Updated teleport-cluster from version 17.0.4 to 17.0.5
- Updated openobserve-collector from version 0.3.15 to 0.3.18
- Updated openobserve from version 0.14.1 to 0.14.7
- Updated oncall from version 1.13.9 to 1.13.11
- Updated mattermost-team-edition from version 6.6.66 to 6.6.67
- Updated argocd-image-updater from version 0.11.2 to 0.11.3
- Updated argo-cd from version 7.7.7 to 7.7.10
- Added opentelemetry-operator from version 0.75.1 to 0.75.1
- Added opentelemetry-operator from version 0.75.1 to 0.75.1
- Updated openobserve-collector from version 0.3.14 to 0.3.15
- Added opentelemetry-operator from version 0.75.1 to 0.75.1
- Added opentelemetry-operator from version 0.75.1 to 0.75.1
- Updated openobserve-collector from version 0.3.14 to 0.3.15

### Improvements
- [`832a1406`](../../commit/832a1406) add kafka operator chart and templates
- [`a84f8da7`](../../commit/a84f8da7) Add proxy mode to keycloak chart due to upgrade to v25
- [`14d71e97`](../../commit/14d71e97) 730 Add openserve-collector & opentelemetry-operator
- [`78691fcc`](../../commit/78691fcc) removing explicit resource namespaces and templatizing secret names
- [`2a6f45c5`](../../commit/2a6f45c5) fix: Update tar command to use updated name after renaming

## 6.3.0

### Minor Version Upgrades

- Updated traefik from version 33.0.0 to 33.1.0
- Updated sonarqube from version 10.7.0+3598 to 10.8.0
- Updated sealed-secrets from version 2.16.2 to 2.17.0
- Updated aws-efs-csi-driver from version 3.0.8 to 3.1.2

### Patch Version Upgrades

- Updated teleport-kube-agent from version 17.0.2 to 17.0.4
- Updated teleport-cluster from version 17.0.2 to 17.0.4
- Added strimzi-kafka-operator from version 0.38.0 to 0.38.0
- Updated rabbitmq-cluster-operator from version 4.3.27 to 4.3.29
- Updated openobserve-collector from version 0.3.14 to 0.3.15
- Updated openobserve-standalone from version 0.13.5 to 0.13.6
- Updated openobserve from version 0.13.5 to 0.13.8
- Updated oncall from version 1.13.3 to 1.13.9
- Updated metallb from version 6.3.15 to 6.3.16
- Updated fluent-bit from version 0.48.1 to 0.48.3
- Updated external-dns from version 8.6.0 to 8.6.1
- Updated crossplane from version 1.18.0 to 1.18.1
- Updated argo-cd from version 7.7.5 to 7.7.7

### Improvements

- [`27bc985d`](../../commit/27bc985d) fix helm repo update script failing to untar newly downloaded chart tar files when naming is different and HELM_UPSTREAM_CHART_VERSION giving unbound variable error when there is no upstream chart already present
- [`59cd0be3`](../../commit/59cd0be3) adding blackbox prober for important services
- [`f906eef5`](../../commit/f906eef5) add steps to add new alerts for servers
- [`c763329f`](../../commit/c763329f) feat: add dashboard if the upstream mixin support it
- [`05ed13ba`](../../commit/05ed13ba) Fix netpol for cert-manager to allow prometheus scrapes
- [`b3e5b381`](../../commit/b3e5b381) add zfs state degrade rule in prometheus linuxaid
- [`0ef419fe`](../../commit/0ef419fe) add mixtool lint check in ci for jsonnet files
- [`877edfda`](../../commit/877edfda) fix mixtool lint
- [`5b1c6824`](../../commit/5b1c6824) Add keycloak Upgrade guide
- [`01982f7d`](../../commit/01982f7d) Make dnszone and dns hostedzone optional for cloudflare
- [`ad626322`](../../commit/ad626322) Add recovery doc for cnpg cluster

## 6.2.0

### Minor Version Upgrades

- Updated velero from version 8.0.0 to 8.1.0

### Patch Version Upgrades

- Updated teleport-kube-agent from version 17.0.1 to 17.0.2
- Updated teleport-cluster from version 17.0.1 to 17.0.2

### Improvements

- [`fdea4476`](../../commit/fdea4476) add mixtool in kubeai ci docker image
- [`a6864eea`](../../commit/a6864eea) feat: build dashboard for all the mixins kubeaid supports
- [`a055b063`](../../commit/a055b063) chore: added mixin-utils needed for grafonnet
- [`8c2bd877`](../../commit/8c2bd877) doc: fix for adding new mixins
- [`2ff09013`](../../commit/2ff09013) chore: added opencost-mixin and mixin-utils v0.14.0 for kube-prom
- [`2d044d25`](../../commit/2d044d25) chore: updated grafananet under v0.13.0 for kube-prom
- [`472b74b4`](../../commit/472b74b4) chore: updated kube-prom libaries
- [`bbf03557`](../../commit/bbf03557) fix: changed the promtool check format in gitea workflow
- [`a8ec4018`](../../commit/a8ec4018) add ci promtool checks for kube-prometheus mixins
- [`d8d9da91`](../../commit/d8d9da91) add missing prometheus rule in mixins
- [`20e85887`](../../commit/20e85887) Fix the spelling mistake
- [`b5b34c84`](../../commit/b5b34c84) deleting main folder from build/kube-prometheus/libraries/main
- [`95313f89`](../../commit/95313f89) fix: expr for mdraid promql rule
- [`10ecae3b`](../../commit/10ecae3b) add mdraid mixin in kube prometheus
- [`3bdc0fc7`](../../commit/3bdc0fc7) add new rule monitor::raid::mdraid::failed, update epr of monitor::raid::mdraid::degraded, and add tests
- [`4f6bcb14`](../../commit/4f6bcb14) feat: mdraid monitoring
- [`ef3de665`](../../commit/ef3de665) (add) : postgresql, redis, and gitea configurations https://gitea.obmondo.com/EnableIT/opsmondo/issues/261
- [`cfa568bd`](../../commit/cfa568bd) (remove) : postgresql and redis dependencies from gitea chart https://gitea.obmondo.com/EnableIT/opsmondo/issues/261
- [`c561f701`](../../commit/c561f701) (add) : gitea chart https://gitea.obmondo.com/EnableIT/opsmondo/issues/261

## 6.1.0

### Minor Version Upgrades

- Updated reloader from version 1.1.0 to 1.2.0
- Updated oncall from version 1.12.1 to 1.13.3
- Updated keycloakx from version 2.5.1 to 2.6.0
- Updated harbor from version 1.15.1 to 1.16.0
- Updated gitlab-runner from version 0.70.3 to 0.71.0
- Updated fluent-bit from version 0.47.10 to 0.48.1

### Patch Version Upgrades

- Updated tigera-operator from version v3.29.0 to v3.29.1
- Updated rook-ceph-cluster from version v1.15.5 to v1.15.6
- Updated rook-ceph from version v1.15.5 to v1.15.6
- Updated opensearch from version 2.27.0 to 2.27.1
- Updated openobserve-standalone from version 0.13.4 to 0.13.5
- Updated openobserve from version 0.13.4 to 0.13.5
- Updated cilium from version 1.16.3 to 1.16.4
- Updated cert-manager from version v1.16.1 to v1.16.2
- Updated argo-cd from version 7.7.3 to 7.7.5

### Improvements

- [`f82edb4b`](../../commit/f82edb4b) fix: added some default resource for puppet-server/db
- [`518ab125`](../../commit/518ab125) fix: tunned puppetserver and puppetdb, so it does not eat too much of memory
- [`3f2140b7`](../../commit/3f2140b7) Add openobserve helm chart
- [`9d52c555`](../../commit/9d52c555) remove zfs exporter
- [`1316dce1`](../../commit/1316dce1) feat: added zfs pool status monitoring
- [`53dbbc78`](../../commit/53dbbc78) add smartmon_sata failure as a mixin in kube-prometheus
- [`5af854dd`](../../commit/5af854dd) add relabeling in prometheus smartctl exporter servicemonitor
- [`82041ba4`](../../commit/82041ba4) add role and rolebinding for prom to scrape it from a respective prometheus namespace
- [`d7ee3cab`](../../commit/d7ee3cab) fix: look for servicemonitor under monitoring and puppetserver for customers

## 6.0.0

### Major Version Upgrades

- Updated velero from version 7.2.2 to 8.0.0
- Updated teleport-kube-agent from version 16.4.6 to 17.0.1
- Updated teleport-cluster from version 16.4.6 to 17.0.1
- Updated redmine from version 30.0.4 to 32.0.1

### Minor Version Upgrades

- Updated whoami from version 5.1.2 to 5.2.0
- Updated external-dns from version 8.5.1 to 8.6.0
- Updated aws-ebs-csi-driver from version 2.36.0 to 2.37.0

### Patch Version Upgrades

- Updated mattermost-team-edition from version 6.6.65 to 6.6.66
- Updated argocd-image-updater from version 0.11.1 to 0.11.2
- Updated argo-cd from version 7.7.0 to 7.7.3

### Improvements

- [`ab5f35b2`](../../commit/ab5f35b2) Fixed the alert query for domains status
- [`6a27021f`](../../commit/6a27021f) bug fix: fixed the env for puppet-agent status monitoring, since default env is master
- [`f678f88f`](../../commit/f678f88f) Added the template file for domain rule
- [`ed1216e8`](../../commit/ed1216e8) Enable domain monitoring
- [`7c06efc9`](../../commit/7c06efc9) Added the alert for domain down
- [`7812104a`](../../commit/7812104a) Fixing AWS InfrastructureProvider Helm template
- [`ddeaa441`](../../commit/ddeaa441) Adding blog : Demonstrating KubeAid (part 0)
- [`4979745e`](../../commit/4979745e) Adding Terraform code for creating a VPC setup for building custom AMIs
- [`9cd9b8c3`](../../commit/9cd9b8c3) fix smartmon disk rule name
- [`6d369aff`](../../commit/6d369aff) rename smart rule to smartmon_disk_health, add doc on how to test rule locally
- [`9288b25c`](../../commit/9288b25c) add smartmon_sata rule to handle sata cable failures
- [`485280ac`](../../commit/485280ac) Fixing KubeadmConfigTemplate not rendering
- [`39e5082d`](../../commit/39e5082d) Fixing indentation for taints in KubeadmConfigTemplate in capi-cluster app
- [`48a75a78`](../../commit/48a75a78) add puppet agent exporter deployment
- [`8142b396`](../../commit/8142b396) add steps for setting up keycloak and giving super user access in matomo
- [`726a1c64`](../../commit/726a1c64) Support Cluster API - Cluster AutoScaler integration

## 5.1.0

### Minor Version Upgrades

- Updated opensearch-dashboards from version 2.24.1 to 2.25.0
- Updated opensearch from version 2.26.1 to 2.27.0
- Updated oncall from version 1.11.5 to 1.12.1
- Updated mariadb-operator from version 0.35.1 to 0.36.0
- Updated keda from version 2.15.2 to 2.16.0
- Updated external-dns from version 8.3.12 to 8.5.1
- Updated crossplane from version 1.17.2 to 1.18.0
- Updated argo-cd from version 7.6.12 to 7.7.0

### Patch Version Upgrades

- Updated sealed-secrets from version 2.16.1 to 2.16.2
- Updated rook-ceph-cluster from version v1.15.4 to v1.15.5
- Updated rook-ceph from version v1.15.4 to v1.15.5
- Updated redmine from version 30.0.2 to 30.0.4
- Updated rabbitmq-cluster-operator from version 4.3.25 to 4.3.27
- Updated opencost from version 1.42.2 to 1.42.3
- Updated metallb from version 6.3.13 to 6.3.15
- Updated cluster-autoscaler from version 9.43.1 to 9.43.2

## 5.0.0

### Major Version Upgrades

- Updated traefik from version 32.1.1 to 33.0.0

### Minor Version Upgrades

- Updated tigera-operator from version v3.28.2 to v3.29.0
- Updated kubernetes-dashboard from version 7.9.0 to 7.10.0

### Patch Version Upgrades

- Updated velero from version 7.2.1 to 7.2.2
- Updated redmine from version 30.0.0 to 30.0.2
- Updated opencost from version 1.42.0 to 1.42.2
- Updated gitlab-runner from version 0.70.2 to 0.70.3
- Updated external-dns from version 8.3.11 to 8.3.12
- Updated argocd-image-updater from version 0.11.0 to 0.11.1

### Improvements

- [`81ba9fea`](../../commit/81ba9fea) fix: cert-manager failed to get parsed, due to templating issue feat: added dnszone support
- [`a40f15a6`](../../commit/a40f15a6) Adding support for specifying root EBS volume size
- [`c9b77dd0`](../../commit/c9b77dd0) fixed the golang version in the dockerfile, after changing the base image
- [`ab50d689`](../../commit/ab50d689) updated the dockerfile to use a noble base image
- [`74a1636e`](../../commit/74a1636e) fix: the context for docker build and removed obsolete options for template workflow
- [`3c0141b3`](../../commit/3c0141b3) fix: run the ci, when the workflow file is change for container image build
- [`32ef499c`](../../commit/32ef499c) fix: the image tag for the kubeaid-ci container image
- [`146230ad`](../../commit/146230ad) removed the bin/tag-update.sh script
- [`fef4c5cb`](../../commit/fef4c5cb) feat: added a support for updating argocd template file with correct tag and added doc as well
- [`38ba0c12`](../../commit/38ba0c12) Add config repo tag updater script and install yq
- [`885d9982`](../../commit/885d9982) update add-commits script to support github commit hash link by adding relative link to commit hash
- [`86107ac2`](../../commit/86107ac2) remove : and add local commit hash linking in changelog for github
- [`7b703a29`](../../commit/7b703a29) Add comment for kubeaid managed apps from cluster specific jsonnet
- [`0405d178`](../../commit/0405d178) Remove redmine app from list of kubeaid apps in Prometheus recording rule
- [`d9e08469`](../../commit/d9e08469) Fix and rename kubeaid managed apps and recording rules for Prometheus
- [`d9153b41`](../../commit/d9153b41) Fixing link to the KubeAid Bootstrap Script container image in KubeAid demo blog (Part 1)

## 4.3.0

### Minor Version Upgrades

- Updated mariadb-operator from version 0.34.0 to 0.35.1
- Updated kubernetes-dashboard from version 7.8.0 to 7.9.0

### Patch Version Upgrades

- Updated yetibot from version 1.0.106 to 1.0.107
- Updated teleport-kube-agent from version 16.4.3 to 16.4.6
- Updated teleport-cluster from version 16.4.3 to 16.4.6
- Updated opensearch-dashboards from version 2.24.0 to 2.24.1
- Updated opensearch from version 2.26.0 to 2.26.1
- Updated oncall from version 1.11.3 to 1.11.5
- Updated mattermost-team-edition from version 6.6.64 to 6.6.65
- Updated gitlab-runner from version 0.70.1 to 0.70.2
- Updated external-dns from version 8.3.9 to 8.3.11
- Updated crossplane from version 1.17.1 to 1.17.2

### Improvements

- [`8f8b179f`](../../commit/8f8b179f) Support for changing memory requests and limits for PostgreSQL in KeycloakX Helm Chart
- [`0acaed4d`](../../commit/0acaed4d) Removed CPU limit for CNPG cluster in KeycloakX helm chart
- [`733f95dc`](../../commit/733f95dc) fixing hbk prometheus
- [`4fb88b73`](../../commit/4fb88b73) (cert-manager) : Simplifying the ClusterIssuer template | Fixes for making the wildcard certificates feature work
- [`1fca8b8c`](../../commit/1fca8b8c) Specifying AWS CLI command to create SSH KeyPair

## 4.2.0

### Minor Version Upgrades

- Updated gitlab-runner from version 0.69.0 to 0.70.1
- Updated aws-ebs-csi-driver from version 2.35.1 to 2.36.0

### Patch Version Upgrades

- Updated teleport-kube-agent from version 16.4.2 to 16.4.3
- Updated teleport-cluster from version 16.4.2 to 16.4.3
- Updated rook-ceph-cluster from version v1.15.3 to v1.15.4
- Updated rook-ceph from version v1.15.3 to v1.15.4
- Updated rabbitmq-cluster-operator from version 4.3.24 to 4.3.25
- Updated oncall from version 1.11.0 to 1.11.3
- Updated mattermost-team-edition from version 6.6.63 to 6.6.64
- Updated keda from version 2.15.1 to 2.15.2
- Updated cluster-autoscaler from version 9.43.0 to 9.43.1
- Updated cloudnative-pg from version 0.22.0 to 0.22.1
- Updated cilium from version 1.16.2 to 1.16.3
- Updated argo-cd from version 7.6.8 to 7.6.12

### Improvements

- [`2c76119b`](../../commit/2c76119b) Adding KubeAid demo blog (Part 1)

## 4.1.0

### Minor Version Upgrades

- Updated oncall from version 1.10.2 to 1.11.0
- Updated mariadb-operator from version 0.33.0 to 0.34.0
- Updated kubernetes-dashboard from version 7.7.0 to 7.8.0
- Updated cluster-api-operator from version 0.13.0 to 0.14.0

### Patch Version Upgrades

- Updated traefik from version 32.1.0 to 32.1.1
- Updated metrics-server from version 3.12.1 to 3.12.2
- Updated k8s-event-logger from version 1.1.7 to 1.1.8
- Updated cert-manager from version v1.16.0 to v1.16.1

### Improvements

- [`d289c927`](../../commit/d289c927) Making CAPI Cluster App's default values file compatible with the optional customerid feature
- [`64f72b7b`](../../commit/64f72b7b) Make customerid optional in CAPI Cluster Helm values
- [`9d18cb83`](../../commit/9d18cb83) add/renamed the references and links to kubeaid
- [`618f0bf3`](../../commit/618f0bf3) Add support for storage blob network rules
- [`261f66a1`](../../commit/261f66a1) enable azure policy

## 4.0.0

### Major Version Upgrades

- Updated redmine from version 29.0.6 to 30.0.0

### Minor Version Upgrades

- Updated traefik from version 32.0.0 to 32.1.0
- Updated sonarqube from version 10.6.1+3163 to 10.7.0+3598
- Updated opensearch-dashboards from version 2.23.0 to 2.24.0
- Updated opensearch from version 2.25.0 to 2.26.0
- Updated oncall from version 1.9.30 to 1.10.2
- Updated kubernetes-dashboard from version 7.6.1 to 7.7.0
- Updated cluster-autoscaler from version 9.41.0 to 9.43.0
- Updated cert-manager from version v1.15.3 to v1.16.0

### Patch Version Upgrades

- Updated rook-ceph-cluster from version v1.15.2 to v1.15.3
- Updated rook-ceph from version v1.15.2 to v1.15.3
- Updated rabbitmq-cluster-operator from version 4.3.23 to 4.3.24
- Updated metallb from version 6.3.12 to 6.3.13
- Updated fluent-bit from version 0.47.9 to 0.47.10
- Updated external-dns from version 8.3.8 to 8.3.9
- Updated argo-cd from version 7.6.5 to 7.6.8

### Improvements

- [`85759c07`](../../commit/85759c07) MachinePool annotation required for the AWS native autoscaler to autoscale it
- [`f43f1e77`](../../commit/f43f1e77) bootstrap crossplane
- [`84054ce6`](../../commit/84054ce6) Change deployment.revisionHistoryLimit type to int from string for Traefik KubeAid app

## 3.0.0

### Major Version Upgrades

- Updated traefik from version 31.1.1 to 32.0.0

### Minor Version Upgrades

- Updated mariadb-operator from version 0.31.0 to 0.33.0
- Updated cluster-autoscaler from version 9.37.0 to 9.41.0

### Patch Version Upgrades

- Updated zfs-localpv from version 2.6.1 to 2.6.2
- Updated teleport-kube-agent from version 16.4.0 to 16.4.2
- Updated teleport-cluster from version 16.4.0 to 16.4.2
- Updated rabbitmq-cluster-operator from version 4.3.22 to 4.3.23
- Updated oncall from version 1.9.25 to 1.9.30
- Updated k8s-event-logger from version 1.1.6 to 1.1.7
- Updated graylog from version 2.3.9 to 2.3.10
- Updated cilium from version 1.16.1 to 1.16.2
- Updated argo-cd from version 7.6.1 to 7.6.5

### Improvements

- [`c0dc582b`](../../commit/c0dc582b) Add network rules for private link access
- [`5854e551`](../../commit/5854e551) Add coredns chart for custom DNS servers (#424)
- [`20683255`](../../commit/20683255) Fix template to allow custom ingressClass for http solver in cert-manager https://gitea.obmondo.com/EnableIT/qd2xcggwag/issues/449

## 2.2.0

### Minor Version Upgrades

- Updated traefik from version 31.0.0 to 31.1.1
- Updated teleport-kube-agent from version 16.3.0 to 16.4.0
- Updated teleport-cluster from version 16.3.0 to 16.4.0
- Updated opensearch-dashboards from version 2.22.0 to 2.23.0
- Updated opensearch from version 2.24.0 to 2.25.0
- Updated haproxy from version 1.22.0 to 1.23.0
- Updated gitlab-runner from version 0.68.1 to 0.69.0
- Updated argo-cd from version 7.5.2 to 7.6.1

### Patch Version Upgrades

- Updated zfs-localpv from version 2.6.0 to 2.6.1
- Updated tigera-operator from version v3.28.1 to v3.28.2
- Updated rook-ceph-cluster from version v1.15.1 to v1.15.2
- Updated rook-ceph from version v1.15.1 to v1.15.2
- Updated redmine from version 29.0.5 to 29.0.6
- Updated metallb from version 6.3.11 to 6.3.12
- Updated crossplane from version 1.17.0 to 1.17.1
- Updated aws-ebs-csi-driver from version 2.35.0 to 2.35.1

### Improvements

- [`f7e69e6c`](../../commit/f7e69e6c) Remove CPU Limits from CrossPlane KubeAid app
- [`def0201d`](../../commit/def0201d) Support for specifying taints for a MachinePool | Adding a NOTE about MachinePool labels
- [`101fadc5`](../../commit/101fadc5) add service monitoring to errbot and update image link

## 2.1.0

### Minor Version Upgrades

- Updated teleport-kube-agent from version 16.2.1 to 16.3.0
- Updated teleport-cluster from version 16.2.1 to 16.3.0
- Updated opensearch-dashboards from version 2.21.2 to 2.22.0
- Updated opensearch from version 2.23.2 to 2.24.0
- Updated mariadb-operator from version 0.30.0 to 0.31.0
- Updated kubernetes-dashboard from version 7.5.0 to 7.6.1
- Updated aws-ebs-csi-driver from version 2.34.0 to 2.35.0

### Patch Version Upgrades

- Updated redmine from version 29.0.4 to 29.0.5
- Updated oncall from version 1.9.22 to 1.9.25
- Updated mattermost-team-edition from version 6.6.62 to 6.6.63
- Updated gatekeeper from version 3.17.0 to 3.17.1
- Updated external-dns from version 8.3.7 to 8.3.8

### Improvements

- [`976335cd`](../../commit/976335cd) (add) : kube-prometheus version 0.14.0 and add-version script
- [`a4b6de55`](../../commit/a4b6de55) Using user specified secret name instead of capi-cluster-token in AWS InfrastructureProvider
- [`9cb20e84`](../../commit/9cb20e84) Using user specified secret name instead of capi-cluster-token in AWS InfrastructureProvider
- [`75a1144a`](../../commit/75a1144a) Upgrade keycloak and remove discarded param
- [`14bad7f9`](../../commit/14bad7f9) Update graylog/upgrading.md with compatibility matrix and reference link
- [`8d6c7028`](../../commit/8d6c7028) Rename graylog6.0.5.md to upgrading.md and update instructions for Graylog and MongoDB upgrade
- [`6784ef4e`](../../commit/6784ef4e) Add readme to Upgrade Graylog and MongoDB to version 6.0.5 and 6.0.16 respectively

## 2.0.0

### Major Version Upgrades

- Updated traefik from version 30.1.0 to 31.0.0

### Minor Version Upgrades

- Updated velero from version 7.1.5 to 7.2.1
- Updated cluster-api-operator from version 0.12.0 to 0.13.0

### Patch Version Upgrades

- Updated teleport-kube-agent from version 16.2.0 to 16.2.1
- Updated teleport-cluster from version 16.2.0 to 16.2.1
- Updated snapshot-controller from version 3.0.5 to 3.0.6
- Updated rook-ceph-cluster from version v1.15.0 to v1.15.1
- Updated rook-ceph from version v1.15.0 to v1.15.1
- Updated rabbitmq-cluster-operator from version 4.3.21 to 4.3.22
- Updated opensearch-dashboards from version 2.21.1 to 2.21.2
- Updated opensearch from version 2.23.1 to 2.23.2
- Updated oncall from version 1.9.20 to 1.9.22
- Updated metallb from version 6.3.10 to 6.3.11
- Updated keycloakx from version 2.5.0 to 2.5.1
- Updated fluent-bit from version 0.47.7 to 0.47.9
- Updated external-dns from version 8.3.5 to 8.3.7

### Improvements

- [`350661b0`](../../commit/350661b0) chore: Remove Middleware and Use Ingress Route
- [`ace356f0`](../../commit/ace356f0) (fix/multiple-machinepool-support) Having multiple KubeadmConfigs - one for each MachinePool
- [`f9d42b03`](../../commit/f9d42b03) Adding AWS CCM as a KubeAid managed app | Removing AWS CCM, Hetzner CCM and Cilium HelmChartProxies | Removing Helm ClusterAPI addon | Installing Cilium and AWS CCM using postKubeadm commands
- [`729be650`](../../commit/729be650) chore: Update middleware name to puppetdb-middlewaretcp.yaml (#398)
- [`cf63dc37`](../../commit/cf63dc37) (fix) : kubeaid-config in example commands
- [`85f13bea`](../../commit/85f13bea) (fix) : kubernetes-config-enableit to kubeaid-config
- [`a07d8448`](../../commit/a07d8448) (clean + update) : remove 7e.. commit and add main vendor files
- [`b550d973`](../../commit/b550d973) (clean) : keeping the generic kubeaid-config repo name
- [`fcc52055`](../../commit/fcc52055) (add) : the latest kube-prom deps https://github.com/prometheus-operator/kube-prometheus/commit/74e445ae4a2582f978bae2e0e9b63024d7f759d6
- [`589fe91f`](../../commit/589fe91f) (docs) : addressing to comment
- [`63d71261`](../../commit/63d71261) (update) : readme with more info
- [`04557af4`](../../commit/04557af4) (docs) : default version
- [`3f35ac66`](../../commit/3f35ac66) (clean) : main stuff
- [`fc236715`](../../commit/fc236715) (fix) : build script with default commit/tag
- [`88bce270`](../../commit/88bce270) (add) : kube-prom main
- [`36529fc6`](../../commit/36529fc6) Adding support for user specified labels for a MachinePool
- [`409aa7d7`](../../commit/409aa7d7) chore: Rename middleware.yaml to puppetdb-middlewaretcp.yaml
- [`a934cf33`](../../commit/a934cf33) chore: Rename middleware.yaml to puppetdb-middlewaretcp.yaml
- [`8e027ee9`](../../commit/8e027ee9) Adding support for multiple MachinePools
- [`1a55b3ea`](../../commit/1a55b3ea) Removing CertManager, ArgoCD, SealedSecrets and AWS EBS HelmChartProxies (they'll be installed using KubeAid)
- [`84694ba7`](../../commit/84694ba7) upgrade argocd

## 1.4.0

### Minor Version Upgrades

- Updated teleport-kube-agent from version 16.1.7 to 16.2.0
- Updated teleport-cluster from version 16.1.7 to 16.2.0
- Updated reloader from version 1.0.121 to 1.1.0
- Updated mariadb-operator from version 0.29.0 to 0.30.0
- Updated crossplane from version 1.16.0 to 1.17.0
- Updated aws-ebs-csi-driver from version 2.33.0 to 2.34.0
- Updated argo-cd from version 7.4.5 to 7.5.2

### Patch Version Upgrades

- Updated whoami from version 5.1.1 to 5.1.2
- Updated rabbitmq-cluster-operator from version 4.3.19 to 4.3.21
- Updated opensearch-dashboards from version 2.21.0 to 2.21.1
- Updated opensearch from version 2.23.0 to 2.23.1
- Updated oncall from version 1.9.12 to 1.9.20
- Updated mattermost-team-edition from version 6.6.61 to 6.6.62
- Updated harbor from version 1.15.0 to 1.15.1

### Improvements

- [`a6d60f64`](../../commit/a6d60f64) Update titles in CHANGELOG, script and add patch dump codition when no helm updates are available since last update
- [`5afabefd`](../../commit/5afabefd) wiki for keycloak custom theme
- [`ed933e77`](../../commit/ed933e77) install cni and ccm as a part of post kubadm commands since its needed for the other nodes to be provisioned
- [`9d5cf60c`](../../commit/9d5cf60c) Update caph version
- [`be13744c`](../../commit/be13744c) use ubuntu 24.04
- [`ca8e8c8f`](../../commit/ca8e8c8f) :no-diff Add procedure for Traefik chart upgrade
- [`84dc17f2`](../../commit/84dc17f2) Revert "Fixed the template to read the correct value for nodes"
- [`9476b6f5`](../../commit/9476b6f5) Fixed the template to read the correct value for nodes
- [`85f033dd`](../../commit/85f033dd) Update the version of k8s and caph
- [`3c192d85`](../../commit/3c192d85) fix: bumped the prometheus version in prom-linuxaid
- [`7146d88c`](../../commit/7146d88c) Fixed lint
- [`5a1ce66e`](../../commit/5a1ce66e) fixed machineDeployment SystemManagedMachiePool
- [`ea3df458`](../../commit/ea3df458) fixed machineDeployment
- [`c492a438`](../../commit/c492a438) Added example value file
- [`81cdd6e8`](../../commit/81cdd6e8) Make default value of azure provider as false
- [`099ab8db`](../../commit/099ab8db) Added loop for machinePool
- [`a113f5cb`](../../commit/a113f5cb) Added loop for machineDeployment
- [`03274d7c`](../../commit/03274d7c) Fixing value file
- [`85326b52`](../../commit/85326b52) Updated readmefile
- [`3875c4b1`](../../commit/3875c4b1) Updated readmefile
- [`16ae93c3`](../../commit/16ae93c3) Added subchart info in chart.yaml
- [`9b9dedf2`](../../commit/9b9dedf2) Added SelfManaged azureClusterAPi
- [`6406970e`](../../commit/6406970e) fix: cert_expiry prom rule fixed in prom-linuxaid, since pushprox is depcrecated now
- [`9c22d854`](../../commit/9c22d854) Adding commented out code for Cilium NetKit support
- [`3ec5e9c3`](../../commit/3ec5e9c3) Removing unnecessary ClusterAPI HelmChartProxy
- [`31bc6afa`](../../commit/31bc6afa) Updating CertManager version and enabling CertManager CRDs to be installed - in HelmChartProxy for ClusterAPI
- [`d924b26c`](../../commit/d924b26c) Adding Cilium specific CNI ingress rules in AWSCluster for ClusterAPI
- [`a15d1f66`](../../commit/a15d1f66) Updating Cilium version to 1.16.0 in ClusterAPI HelmChartProxy

## 1.3.0

### Minor Version Upgrades

- Updated traefik from version 30.0.2 to 30.1.0
- Updated rook-ceph-cluster from version v1.14.9 to v1.15.0
- Updated rook-ceph from version v1.14.9 to v1.15.0
- Updated prometheus-adapter from version 4.10.0 to 4.11.0
- Updated postgres-operator from version 1.12.2 to 1.13.0
- Updated opensearch-dashboards from version 2.20.0 to 2.21.0
- Updated opensearch from version 2.22.0 to 2.23.0
- Updated opencost from version 1.41.0 to 1.42.0
- Updated oncall from version 1.8.9 to 1.9.12
- Updated keycloakx from version 2.4.4 to 2.5.0
- Updated gitlab-runner from version 0.67.1 to 0.68.1
- Updated gatekeeper from version 3.16.3 to 3.17.0
- Updated cloudnative-pg from version 0.21.6 to 0.22.0
- Updated cerebro from version 2.0.5 to 2.1.0

### Patch Version Upgrades

- Updated velero from version 7.1.4 to 7.1.5
- Updated teleport-kube-agent from version 16.1.4 to 16.1.7
- Updated teleport-cluster from version 16.1.4 to 16.1.7
- Updated redmine from version 29.0.3 to 29.0.4
- Updated rabbitmq-cluster-operator from version 4.3.18 to 4.3.19
- Updated mattermost-team-edition from version 6.6.60 to 6.6.61
- Updated keda from version 2.15.0 to 2.15.1
- Updated graylog from version 2.3.8 to 2.3.9
- Updated fluent-bit from version 0.47.5 to 0.47.7
- Updated external-dns from version 8.3.4 to 8.3.5
- Updated cilium from version 1.16.0 to 1.16.1
- Updated cert-manager from version v1.15.2 to v1.15.3
- Updated argo-cd from version 7.4.2 to 7.4.5

### Improvements

- [`f931fffe`](../../commit/f931fffe) updated the prometheus metrics alert to handle boot time as well
- [`44a0e0ec`](../../commit/44a0e0ec) Add add-commit bash script and call it in helm-repo-update script and update CHANGELOG with commits as per new standard
- [`a3293137`](../../commit/a3293137) refactor: Update TCP ingress route for puppetdb to use new domain name
- [`e40cfb96`](../../commit/e40cfb96) fixed the alert expression for node which are not sending metrics within the timefram
- [`a74fb76d`](../../commit/a74fb76d) feat: Add TCP ingress route for puppetdb
- [`5be86fec`](../../commit/5be86fec) refactor: Update IP allowlist in puppetserver middleware.yaml
- [`6ad2a8ae`](../../commit/6ad2a8ae) feat: Add middleware for IP allowlist in puppetserver ingress route
- [`d706ddce`](../../commit/d706ddce) fixed the watchdog alert to alert if alertmanager are not sending the watchdog alert within a time-frame
- [`2780a6f2`](../../commit/2780a6f2) fix: job name of opsmondo
- [`1c8c9ab0`](../../commit/1c8c9ab0) [FEAT] add default value for networkpolicies
- [`0baf17c1`](../../commit/0baf17c1) change matomo version to 5.1.1
- [`cb080daf`](../../commit/cb080daf) wildcard certificates should be set to disabled as a default
- [`35adfd74`](../../commit/35adfd74) need kind in ingressroute object
- [`4019afc4`](../../commit/4019afc4) removed middleware from ingressroute, it was never working, and its moved to client cert auth
- [`dcf43853`](../../commit/dcf43853) upgrade prom/alertmanager and grafana version in prom-linuxaid helm chart
- [`e6c69984`](../../commit/e6c69984) [FEAT] add netpol template to fluentbit
- [`730161c0`](../../commit/730161c0) changed the alert expr for arogcd-app which are unhealthy and outofsync
- [`f1e1a7d6`](../../commit/f1e1a7d6) removed .gitignore from the kubeaid list and fixed metadata.name for promrule and added a default project
- [`2973d15b`](../../commit/2973d15b) added support for monitoring oosync apps of argocd, for now only kubeaid apps
- [`16945fb8`](../../commit/16945fb8) removed puppetserver image and tag and let it come from upstream default values file
- [`0f3414e4`](../../commit/0f3414e4) removed mastersfor ingressroute for puppetserver, since we cant generate new CA cert, if new customer/users comes up. otherwise we will have re-gen all the cert of the puppet agent, which is not feasible
- [`70d0b5c3`](../../commit/70d0b5c3) fixed puppetserver values file to be more generic
- [`70c04e7c`](../../commit/70c04e7c) changed the cron time for puppet git pull
- [`dd69e2ca`](../../commit/dd69e2ca) Installing tzinfo-data to puppet server
- [`cc87bbec`](../../commit/cc87bbec) fixed the puppetserver helm chart bug when mounting eyaml
- [`3711dd68`](../../commit/3711dd68) added an empty value for ingressrotue for puppetserver
- [`468c7076`](../../commit/468c7076) fix: handle puppet agent for user which has few puppet agent
- [`2b6dee6d`](../../commit/2b6dee6d) removed prometheus report setting, since its not setup entirely
- [`c6a9b090`](../../commit/c6a9b090) added a custom gem to be installed, need by one of the puppet function on linuxaid
- [`0207de09`](../../commit/0207de09) added node_terminus setting in puppet server section
- [`43ef8c98`](../../commit/43ef8c98) fixed the customentrypoints bug in values file for puppetserver
- [`3a1d5010`](../../commit/3a1d5010) added enc support and updated readme as well
- [`7f02e48e`](../../commit/7f02e48e) removed options from ingressroutetcp as its not wanted
- [`fda279cd`](../../commit/fda279cd) fixed the autosign path for puppetserver
- [`8ed24a46`](../../commit/8ed24a46) added autosign script puppetserver
- [`3d92261b`](../../commit/3d92261b) migrated the ingressroute to ingressroutetcp and removed options as per the tcp spec
- [`af1ff6c7`](../../commit/af1ff6c7) changed the object name from ingressroute to ingressroutetcp
- [`16a606ea`](../../commit/16a606ea) added passthrough and remove certresolver, since we dont need it
- [`fde8302d`](../../commit/fde8302d) added ingressroute and disabled ingress
- [`7d742f78`](../../commit/7d742f78) Fix providers and upgrad vpc module
- [`76b51ba3`](../../commit/76b51ba3) update helm-repo-update script with logging in changelog, auto tag bumping according to helm charts being updated and update commit structure
- [`0edee695`](../../commit/0edee695) doc: updated readme and an example netrc file
- [`f8f23501`](../../commit/f8f23501) lets not run r10k as sidecar, to avoid multiple container for it and fixed the r10k spec issue, entered in the wrong place
- [`967e92d8`](../../commit/967e92d8) added puppeturl and secret to access the puppet git repo
- [`a0bf9874`](../../commit/a0bf9874) wip
- [`a553cce0`](../../commit/a553cce0) fixed the ingress alignment
- [`2e5db425`](../../commit/2e5db425) fix: fixed the env and secret name as per new object name for puppetserver
- [`86a3774a`](../../commit/86a3774a) fix: added namespace support to postgresql puppetserver
- [`334bfb84`](../../commit/334bfb84) fixes:

## 1.2.0

### Minor Version Upgrades

- Updated opensearch-dashboards from version 2.19.1 to 2.20.0
- Updated opensearch from version 2.21.0 to 2.22.0
- Updated community-operator from version 0.10.0 to 0.11.0

### Patch Version Upgrades

- Updated teleport-kube-agent from version 16.1.3 to 16.1.4
- Updated teleport-cluster from version 16.1.3 to 16.1.4
- Updated rabbitmq-cluster-operator from version 4.3.17 to 4.3.18
- Updated metallb from version 6.3.9 to 6.3.10
- Updated aws-efs-csi-driver from version 3.0.7 to 3.0.8
- Updated argo-cd from version 7.4.1 to 7.4.2

### Improvements

- [`ca279e10`](../../commit/ca279e10) Update changelog format
- [`a553cce0`](../../commit/a553cce0) fixed the ingress alignment
- [`c78a3a5b`](../../commit/c78a3a5b) small spelling fix and add log delition and garbage collection history
- [`52b24a6d`](../../commit/52b24a6d) harbor clean up doc
- [`ca004f96`](../../commit/ca004f96) Fixed cilium template condition
- [`044ed1b6`](../../commit/044ed1b6) Added a readme file for azure cluster api
- [`2e5db425`](../../commit/2e5db425) fix: fixed the env and secret name as per new object name for puppetserver
- [`86a3774a`](../../commit/86a3774a) fix: added namespace support to postgresql puppetserver
- [`334bfb84`](../../commit/334bfb84) fixes:
- [`62e841a7`](../../commit/62e841a7) Added a helm chart for azure cluster api
- [`98f94caa`](../../commit/98f94caa) Fixed Yaml linting
- [`d6f40a65`](../../commit/d6f40a65) Added capz version
- [`edf3a588`](../../commit/edf3a588) Added Azure capz helm chart
- [`5c93bc15`](../../commit/5c93bc15) setup matomo in k8s

## 1.1.0

### Minor Version Upgrades

- Updated keda from version 2.14.2 to 2.15.0
- Updated cluster-api-operator from version 0.11.0 to 0.12.0
- Updated argo-cd from version 7.3.11 to 7.4.1

### Patch Version Upgrades

- Updated teleport-kube-agent from version 16.1.0 to 16.1.3
- Updated teleport-cluster from version 16.1.0 to 16.1.3
- Updated reloader from version 1.0.119 to 1.0.121
- Updated rabbitmq-cluster-operator from version 4.3.16 to 4.3.17
- Updated oncall from version 1.8.8 to 1.8.9
- Updated keycloakx from version 2.4.3 to 2.4.4
- Updated external-dns from version 8.3.3 to 8.3.4
- Updated dokuwiki from version 16.2.10 to 16.2.11

## 1.0.0

### Major Version Upgrades

- Updated matomo from version 7.3.7 to 8.0.5
- Updated redmine from version 28.2.7 to 29.0.3
- Updated traefik from version 29.0.0 to 30.0.2

### Minor Version Upgrades

- Updated aws-ebs-csi-driver from version 2.32.0 to 2.33.0
- Updated cilium from version 1.15.6 to 1.16.0
- Updated external-dns from version 8.1.0 to 8.3.3
- Updated fluent-bit from version 0.46.11 to 0.47.5
- Updated gitlab-runner from version 0.66.0 to 0.67.1
- Updated opencost from version 1.40.0 to 1.41.0

### Patch Version Upgrades

- Updated argo-cd from version 7.3.4 to 7.3.11
- Updated aws-efs-csi-driver from version 3.0.6 to 3.0.7
- Updated cert-manager from version v1.15.1 to v1.15.2
- Updated cloudnative-pg from version 0.21.5 to 0.21.6
- Updated dokuwiki from version 16.2.6 to 16.2.10
- Updated mattermost-team-edition from version 6.6.58 to 6.6.60
- Updated metallb from version 6.3.7 to 6.3.9
- Updated oncall from version 1.8.1 to 1.8.8
- Updated opensearch-dashboards from version 2.19.0 to 2.19.1
- Updated rabbitmq-cluster-operator from version 4.3.13 to 4.3.16
- Updated reloader from version 1.0.116 to 1.0.119
- Updated rook-ceph from version v1.14.8 to v1.14.9
- Updated rook-ceph-cluster from version v1.14.4 to v1.14.9
- Updated sealed-secrets from version 2.16.0 to 2.16.1
- Updated sonarqube from version 10.6.0+3033 to 10.6.1+3163
- Updated tigera-operator from version v3.28.0 to v3.28.1
- Updated velero from version 7.1.0 to 7.1.4

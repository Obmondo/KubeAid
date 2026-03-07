# KubeAid Operations Tips

> [!WARNING]
> This document contains legacy operational procedures. Some information may be outdated.
> Please refer to the [Getting Started Guide](../getting-started/README.md) for current installation instructions.

This repository (https://github.com/Obmondo/KubeAid) implements a solution to run any Kubernetes cluster, using GitOps
principles and allowing for customisation, in a separate repository.

This way you can always pull the latest commits, and get security updates, fixes, new features etc., while still being
able to do your own adjustments.

This is copyright EnableIT ApS (of Denmark) and released under GPL 3 license of fsf.org.

[Obmondo](https://obmondo.com) offers subscriptions, where we manage your Kubernetes cluster, using this code, and
react to incidents 24/7/365 if this should be of interest.

In this way, we typically help out smaller setups, where there is only 1 or 2 operations people, and hence 24/7
operations isn't possible to run reliably - with our subscription, we take care of the 24/7 monitoring and our
knowledgeable developers and operations people are ready to resolve any issues that may arise - while you can work on
the day 2 day stuff, as you'd usually do - and still get your vacations, weekends etc. without having to be on-call
yourself.

## Security design goals

This operations design, is designed to deliver a setup, that delivers on all 3 aspects of security Confidentiality,
Integrity and Availability.

### Confidentiality

This setup uses Calico CNI - and ensure network filtering - on both ingress and egress - which means we work hard to
avoid any pod in this cluster, has (or needs) internet access. In this way, should a compromise of a pod happen - its
harder to get data out, or pull necessary code from the internet to further exploit your systems.

You can disable network filtering for any application - but do so at your own peril - with above risk in mind.

### Integrity

#### Helm chart security

We store EVERY Helm chart from an application upstream inside this repository. This has the following benefits:

- You can always install your application/do recovery - with no internet needed. If an upstream chart repo is down
  this will not affect you (and this happens quite often when you have many sources/charts in use).
- On EVERY upgrade, we review the diff of the chart for any unexpected changes, and this way we HOPE to catch a
  compromised upstream release, before its included in this repository.
  - At the very least we can see from how other it has been found that other codebases has been compromised - that this
    is the structure that enabled it to be detected.
- We run a CI job, that daily fetches the same charts we have in our repo, from upstream chart repo - and check if
  upstream matches OUR copy. If it does not:
  - Upstream updated an existing release - which is a VERY BAD idea.
  - Upstream Helm repo suffered a supply-chain attack

### Docker image security

We change EVERY docker image, to use the `sha256sum` of the docker image instead of the tag. This means if upstream mirror
(e.g. Docker Hub) is compromised (and tag pointing to different docker image) - we will still get the original image -
or fail.

This repository has a CI job, that on every MR / PR fetches docker images used and pushes to YOUR docker registry (in
GitLab, Github Docker service or whatever you prefer), so your Kubernetes cluster doesn't talk to anything on the
Internet to pull the necessary Docker images for operations.

Here we also run a daily CI job to compare tag to the `sha256sum` we have, to detect any supply chain attacks (which
won't affect those using this setup) so they can be reported upstream.

We scan Docker images used for known vulnerabilities (software in image with known CVE f.ex.) and report upstream, and
if upstream will accept it we will gladly submit fixes to upstream to avoid users of this repository deploying
vulnerable code.

### Availability

## Repository structure

This repo contains all the kubernetes applications helm charts that are used on Enableit managed clusters, and the
install script for setting up a new cluster with root app. In `build` there is also a script for setting up
kube-prometheus. Each customer has their own kubernetes-config repo, and each cluster has a folder in such a repo. This
repo works in tandem with those cluster folders, they reference the charts stored here, and the install scripts here
create the content in those folders.

| `folder`                       | `description`                                                                                                                                                                                                                                                                          |
|--------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `argocd-helm-charts`           | Contains ArgoCD helm charts, that points to the actual helm charts (as a dependency listed in `Charts.yaml`) - and with the default values we want. Each cluster can add override/extra values by listing an extra values file in their `argocd-clusters-managed/$clustername` folder. |
| `argocd-k8sconfig`             | Kubernetes config objects. Used by all in `common` and per-cluster in their individual `$clustername` folder.                                                                                                                                                                          |
| `argocd-application-templates` | collection of applications, to be optionally modified and copied into `argocd-clusters-managed/$clustername/templates` to be installed on that cluster.                                                                                                                                |
| `build`                        | contains script and config files for installing kube-prometheus on a cluster, has its own README with usage guide                                                                                                                                                                      |

## Install ArgoCD on a cluster and add it to this repository

### PREREQUISITE

- `kubectl`, `helm`, `kubeseal`, `bcrypt-tool` and `pwgen`
- you can connect to k8s from your work station/laptop/desktop.
- See wiki/guides/kubernetes-desktop-setup on how to install everything including switch

  ```sh
  # optionally switch cluster
  switch
  # To verify
  kubectl get nodes
  ```

- To generate access token for `https` access and for GitHub repo follow [this guide](https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps#generating-a-private-key)

  ```fundamental
  # https://gitlab.enableit.dk/kubernetes/kubernetes-config-enableit/-/settings/access_tokens
  > Give token name
  > "read_repository" scopes
  > "Maintainer" role
  > submit
  ```

- Generate username and password for OCI

  ```fundamental
  # TODO: We dont use OCI currently. Update this when it is implemented.
  ```

- create git repo for customer k8s data. it SHOULD be in this format only `kubernetes-config-<customer-id>` and sits at
  the same level where your `argocd-apps` is cloned

  ```fundamental
  # https://gitlab.enableit.dk/kubernetes/kubernetes-config-enableit.git
  ```

- Wiki `wiki/guides/kuberenetes-desktop-setup.md`

## Setup K8s cluster

### Puppet

1. For puppet managed cluster

   ```sh
   ./bin/generate-puppet-hiera.sh --cluster-name kam.obmondo.com --version 1.22.5 --san-domains kam.obmondo.com,localhost,176.9.67.43,htzsb44fsn1a.enableit.dk:78.46.72.21,htzsb45fsn1a.enableit.dk:176.9.124.207,htzsb45fsn1b.enableit.dk:85.10.211.48 --customer-id enableit
   ```

2. Login onto server and run puppet
3. If things got broken refer to wiki/guides/kubernetes-cluster-setup.md
4. Run cluster setup script:

   ```sh
   ./bin/setup-k8s-cluster.sh --customer-id enableit --cluster-name kam.obmondo.com --settings-file <path-to-file>/customer-settings.yaml --install-k8s false
   ```

5. push all the files to git repo from the `kubernetes-config-<customer-id>` git repo
6. Add the ArgoCD password in pass repo (you will get the password in step 4)

### KOPS

1. Get the k8s cluster up and running with KOPS with one single command line.

   ```sh
   ./bin/setup-k8s-cluster.sh --customer-id <customer-id> --cluster-name <cluster-name> --settings-file <path-to-settings-file> --k8s-type kops
   ```

2. Add the ArgoCD password in pass repo (you will get the password in step 1)

## Uninstall script

Always run uninstall script with `--keep-files` or it wont save the keys for reading sealed secrets.

```sh
./bin/uninstall-argocd.sh --keep-files
```

This will remove sealed-secrets and all argocd apps and argocd itself from the current k8s context (undoing install script)
It will prompt for cluster_name and argocd password (which you recieved from the install script)

## Recovery mode

The install script has a `--recovery` mode which you use by calling them like this.

```sh
./bin/setup-k8s-cluster.sh --customer-id enableit --cluster-name kam.obmondo.com --settings-file customer-settings.yaml --recovery --private-key-path private_keys --public-key-path public_keys --install-k8s false
```

In recovery mode the install script will install argocd using the existing manifests in your local repo clone.

### Recover ArgoCD password

```sh
./bin/setup-k8s-cluster.sh --cluster-name k8s.staging.blackwoodseven.com --settings-file customer-settings.yaml --setup-root-app false --recovery --private-key-path ./private_keys --public-key-path ./public_certs --customer-id bw7 --install-k8s false --setup-sealed-secret false
```

install script will install ArgoCD using the existing manifests in your local repo clone.

### For SSH access to git repositories

Note: **we don't support this**

Setup GitLab user and generate SSH key set (and add public part to that GitLab user). Grant that user ONLY developer
access to the projects it needs. Make sure those have master branch and tags protected in config.

add secret with ssh keys for GitLab ArgoCD SSH access:

```sh
kubectl create secret generic argocd-sshkey --from-file=ssh-privatekey=/path/to/.ssh/id_rsa --from-file=ssh-publickey=/path/to/.ssh/id_rsa.pub
```

Make sure `sshPrivateKeySecret.name` for repositories in `argocd-clusters-managed/$yourclustername/values-argocd.yaml`
has this repo added, matching above secret name.

A command to get the existing ssh private key

```sh
kubectl get secrets -n argocd argo-cd-enableit-gitlab-ssh -o jsonpath="{.data.ssh-privatekey}" | base64 --decode
```

Login to the UI. To get the credentials refer
[ArgoCD admin credentials](https://argoproj.github.io/argo-cd/getting_started/#4-login-using-the-cli).

## About the root app

The install script adds root.yaml to the cluster folder under argocd-apps/templates in kubernetes-config-customerid.
This argocd app has the clusters argocd-apps folder as its path. Making argocd detect all the apps in there
automatically. So we can install apps just by adding them to the clusters argocd-apps folder in the customers
kubernetes-config repo, and then syncing with argocd.

## Secrets handling

- If a helm chart creates a secret - ArgoCD will expect it to remain unchanged
  (otherwise complain application is out-of-sync).
- If this happens it means you have a secret that's changed via the application (typically user login password), and we
  **NEED** backup of these.

To resolve out-of-sync complaint in ArgoCD - AND backup/recovery do this:

1. let helm chart create secret and application generate it - so you get out-of-sync complaint from ArgoCD.
2. dump secret in JSON format, remove unnecessary metadata/Helm labels and
   encode into cluster secrets repo and delete the secret from k8s (before
   pushing to secrets repo).
3. update values for chart as to NOT generate secret. Typically the setting is
   called something like `useExistingSecret: $name-of-secret`

## Debugging

- you might see pods getting evicted, mostly likely disk is used around 70% or you have less disk size (`> 5GB`). to fix
  it increase the disk size

  ```fundamental
  root@htzsb44fsn1a ~ # kubectl get pods
  NAME                                                    READY   STATUS    RESTARTS   AGE
  argo-cd-argocd-application-controller-d6c576f5d-4d9bv   0/1     Evicted   0          84m
  argo-cd-argocd-application-controller-d6c576f5d-5xwq5   0/1     Evicted   0          44m
  argo-cd-argocd-application-controller-d6c576f5d-7cm78   0/1     Evicted   0          100m
  ```

- It's important to ensure that: `acme.cert-manager.io/http01-edit-in-place: true` is placed in annotations for ingress
  when `traefik` is used

- Please refer: [Wiki for kubernetes](https://gitlab.enableit.dk/obmondo/wiki/-/tree/master/internal/kubernetes)

## Testing applications - before doing a PR / MR

### Test helm values generate the YAML you want

1. run `helm dep`

   ```sh
   helm dep up argocd-helm-charts/<nameofchart>
   ```

2. run `helm template`

   ```sh
   helm template argocd-helm-charts/<nameofchart> --values ../kubernetes-config-<customer-id>/k8s/<targetcluster>/argocd-apps/values-<nameofchart>.yaml >/tmp/before.yaml
   ```

3. Read YAML and see if you like it.
4. Adjust values to your liking and run step 2 again, saving the result to `/tmp/after.yaml`.
5. Check the difference by running `diff -bduNr /tmp/before.yaml /tmp/after.yaml` and verify the changes your value
   update should have caused are present.

### Install the application manually to verify

1. create/copy application YAML and set: `targetRevision` to `$yourbranchname`
   instead of `HEAD`
2. Load that YAML manually (`kubectl create -ns argocd -f yourapplication.yaml`)
3. Work in your branch - adjust values as needed etc.
4. When it works: simply update the application YAML to pointing to
   `targetRevision: HEAD` and make your MR/PR

## General idea/Working of pointing apps to GHRC

1. Main script - `helm-chart-cache.sh`
2. Run `helm-chart-cache.sh` script.

```sh
bash helm-chart-cache.sh -u <Username> -p <Password> -r <Registry>
```

In the above:

```fundamental
u - Username to login to your registry. Eg - Obmondo
p - Password. Here you need to pass the PA token which you can create on your Github profile
r - Name of the registry. Eg - ghcr.io/Obmondo
```

This script will first download the charts from Upstream repo and then save and
push it your registry. When the script has run without any issues it will update
the `Chart.lock` file of your charts to point it your OCI repo path. So, you
need to just commit and push the Chart.lock file and then your apps will start
pointing to GHCR.

Remember: the lock file will only change for charts which are still not in your
registry.

## Fix ssh mismatch key when the Change/Update of git server

- Repository which are configured via ssh might end up not working, since the ssh known_host key is changed.
- To fix
  1. `ssh-keyscan -p <your-port-number> <git-server>`
  2. Copy the `ecdsa-sha2-nistp256` key pair type. Other types might work too, but we haven't tried it.
  3. Now the ArgoCD won't be working, since it can't connect to the git server.
  4. Go to repository and click on 'Certificates' and remove the old entry and create a new one and add the key that you
     got from `ssh-keyscan`
  5. Go to application and click on the `argo-cd` and sync the `argocd-ssh-known-hosts-cm` and then it should work

## Automatic pull requests on change

### GitHub

See https://github.com/Obmondo/github-action-obmondo-deploy

### GitLab

- `KUBERNETES_CONFIG_REPO_TOKEN` At [/project access
  token/](https://docs.gitlab.com/ee/user/project/settings/project_access_tokens.html) used for accessing the config
  repo.

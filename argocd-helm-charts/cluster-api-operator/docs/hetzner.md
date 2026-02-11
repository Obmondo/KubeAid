# Syself Hetzner CAPH (Robot + Cloud)

## Background

* CAPH (Cluster API Provider Hetzner) which will takecare of node lifecycle

* Syself has developed CAPH which works with hetzner robot, the official only supported the cloud.
  But good news is that syself changes are merged into official
  [here is the PR](https://github.com/hetznercloud/hcloud-cloud-controller-manager/pull/561/)

  **NOTE** The official ccm didn't worked for me, so currently we are using ccm from syself.

## Pre-Requisites

* Create webservice user on Hetzner Goto [Settings](https://robot.hetzner.com/preferences/index) and
  follow more instruction
  [here](https://github.com/syself/cluster-api-provider-hetzner/blob/main/docs/topics/preparation.md#preparing-hetzner-robot)

* Generate API Token [here](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/)

## Setup

* Setup required envs

  ```sh
  #!/bin/bash

  export CLUSTER_NAME=k8s03.obmondo.com \
  export CUSTOMER_ID=lkaeu2839 \
  export HCLOUD_SSH_KEY="cluster" \
  export HCLOUD_TOKEN="xxx" \
  export HETZNER_ROBOT_USER="xxx" \
  export HETZNER_ROBOT_PASSWORD="xxx" \
  export HETZNER_SSH_PUB_PATH= "/home/foo/.ssh/robot_id_rsa.pub" \
  export HETZNER_SSH_PRIV_PATH="/home/foo/.ssh/robot_id_rsa" \
  export ARGOCD_KUBEAID_CONFIG_REPO_URL=https://github.com/Obmondo/kubeaid-config-enableit.git \
  export ARGOCD_REPO_TOKEN=xxx \
  export ARGOCD_REPO_USERNAME=kubeaid-bot \
  export GIT_KUBEAID_CONFIG_REPO_URL=https://github.com/Obmondo/kubeaid-config.git \
  export KUBEAIDCONFIG=~/.kube/config
  ```

* Create required secrets

  ```sh
  kubectl -n capi-cluster-$CUSTOMER_ID create secret generic capi-cluster-hetzner --dry-run=client --from-literal=hcloud=$HCLOUD_TOKEN --from-literal=robot-user=$HETZNER_ROBOT_USER --from-literal=robot-password=$HETZNER_ROBOT_PASSWORD -o yaml | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets -o yaml > capi-cluster-hetzner.yaml

   kubectl -n capi-cluster-$CUSTOMER_ID create secret generic capi-cluster-robot-ssh --dry-run=client --from-literal=sshkey-name=cluster --from-file=ssh-privatekey=$HETZNER_SSH_PRIV_PATH --from-file=ssh-publickey=$HETZNER_SSH_PUB_PATH -o yaml | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets -o yaml > capi-cluster-robot-ssh.yaml
  ```

* Sync the capi-cluster-<cluster-name> app on argo-cd

* Make sure the floating IP is pointing to correct node on robot UI [look at the node which cluster-api picked up to provision on mgmt cluster]

* Get the new cluster kubeconfig

  ```sh
  clusterctl get kubeconfig -n capi-cluster kcm > /tmp/x.config
  ```

* Make sure to remove the taint from control-plane nodes, so it can schedule the pod

```yaml
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
```

## Troubleshootings

* Node will be restart again and again, simply delete the machine from cluster, for forcefull, remove the finalizers

* CCM needs to be running on end cluster and **only** after that the rest of the node will be provisioned by the cluster-api [here](https://github.com/syself/cluster-api-provider-hetzner/issues/252)

## Guide

[Quickstart](https://github.com/syself/cluster-api-provider-hetzner/blob/main/docs/topics/quickstart.md)

## TODO

* Make sure the floating IP is pointing to correct node on robot UI [Needs to be via CAPH provider, or via a deployment, currently hclodu is support https://github.com/costela/hcloud-ip-floater]

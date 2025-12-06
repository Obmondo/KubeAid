#!/bin/bash
set -euo pipefail
# IMPORTANT: This script assumes that you have port-forward to argocd running on localhost:8080
# kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:80
# Also this script must be run from the root of the argocd-apps repo

CANCEL_UNINSTALL() {
    echo "Canceling uninstall"
    exit 1
}
DEPFAIL() {
    echo "ERROR missing dependency: $1"
    echo "See wiki/guides/kubernetes-desktop-setup.md for how to install it"
    CANCEL_UNINSTALL
}
for program in kubectl helm
do
    if [ -z "$(which ${program})" ]; then
        DEPFAIL "$program"
    fi
done

# The argocd namespace should exist
if [[ ! " $(kubectl get namespaces -o 'jsonpath={.items[*].metadata.name}') " =~ " argocd " ]]; then
    echo 'ERROR: argocd namespace already doesnt exists!'
    CANCEL_UNINSTALL
fi

echo "Uninstalling argocd with all its apps, and sealed secrets"

keep_files=
if [ "${1-}" = "--keep-files" ]; then
    keep_files=true
fi
if [ -n "$keep_files" ]; then
    echo "Using keep_files mode: Manifests in local repo will not be removed."
fi

read -r -p "Enter cluster name:" cluster_name
read -r -p "Enter the argocd password: " password

secret_name="argocd-${cluster_name}-github"

if [ -n "$keep_files" ]; then
    # Loop for getting all sealed secrets controller private and pub keys
    # Make dirs for all keys
    private_key_dir=./sealed-secrets/"$cluster_name"/controller-private-keys
    public_key_dir=./sealed-secrets/"$cluster_name"/controller-public-keys
    #rm old saved keys (we are going to replace them now)
    rm -rf "$private_key_dir"
    rm -rf "$public_key_dir"
    mkdir "$private_key_dir"
    mkdir "$public_key_dir"

    # While there are still sealed-secrets controller keys, save them locally and remove them form kubernetes
    until [ "$(kubectl -n system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o jsonpath={..items})" = '[]' ]; do
        # Get name of first key
        current_key_secret=$(kubectl -n system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o jsonpath={..items[0].metadata.name})
        # Get keys
        kubectl -n system get secret/"$current_key_secret" -o jsonpath={..data."tls\.key"} | base64 -d > "$private_key_dir"/"$current_key_secret".key
        kubectl -n system get secret/"$current_key_secret" -o jsonpath={..data."tls\.crt"} | base64 -d > "$public_key_dir"/"$current_key_secret".crt
        # Delete secret from kubernetes
        kubectl -n system delete secret/"$current_key_secret"
    done
fi

echo "Getting argocd API login token"
argocd_login_token=$(curl http://localhost:8080/api/v1/session -d "{\"username\":\"admin\",\"password\":\"$password\"}" | cut -d '"' -f 4)

sleep 2s

echo "Deleting apps from argocd"
app_name=$(curl --cookie "argocd.token=$argocd_login_token" "http://localhost:8080/api/v1/applications" | jq .items[0].metadata.name | tr -d '"')
until [ "$app_name" = "null" ]; do
    echo "Deleting argocd app $app_name"
    curl --cookie "argocd.token=$argocd_login_token" -X DELETE "http://localhost:8080/api/v1/applications/$app_name?cascade=false"
    app_name=$(curl --cookie "argocd.token=$argocd_login_token" "http://localhost:8080/api/v1/applications" | jq .items[0].metadata.name | tr -d '"')
done
echo "All apps removed"

if [ -z "$keep_files" ]; then
    echo "Deleting cluster folder and clusters sealed secrets folder"
    rm -rf ./sealed-secrets/"$cluster_name"
    rm -rf ./argocd-clusters-managed/"$cluster_name"
fi

echo "Uninstalling argo-cd and deleting namespace"
kubectl -n argocd delete secret/"$secret_name"
helm -n argocd uninstall argo-cd
kubectl config set-context --current --namespace=default
kubectl delete namespace/system
kubectl delete namespace/argocd

echo "Uninstall completed"
#If namespace is stuck in "Terminating", you can use this to see remaining
#resources in the argocd namespace. If there are no resources it just takes a
#little while for the namespace to disappear
# microk8s.kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 microk8s.kubectl get --show-kind --ignore-not-found -n argocd
# kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n argocd
# You probably have to edit them and delete the line under "finalizers:"

# Argo CD

## Setup root argocd application

* After your kube cluster is created - you will need to deploy the root application
  Assuming you have already created the `k8s/<clustername>/argocd-apps` in your kubeaid-config repo

  ```sh
  helm template k8s/<clustername>/argocd-apps --show-only templates/root.yaml | kubectl apply -f -
  ```sh

## How ArgoCD works with Helm

Argocd generates kubernetes yaml objects, by running Helm template command on the chart, with the
values files given in the Application. It then inserts those objects itself - so you CANNOT use Helm
to operate on the cluster directly (and should not - since that is NOT a GitOPS way of working! - see
guides on gitops)

This means that to make something different in Kubernetes objects, you MUST do it, by ONLY modifying
values files for charts.

If a chart does not support what we need - ask your colleagues and consult upstream Chart maintainers
(typically via github issues) to see if the feature we need has been asked about previously - and if
not - if they would be interested in getting a PR for it. We DO NOT do changes, that upstream won't
accept (as that would be the same as forking the project).

## Tips on ArgoCD UI

* out-of-sync does not mean missing necessarily. look at application diff (in compact view)
* NEVER do force/replace on argocd (as that will KILL argocd - which means it won't finish)
* argocd does NOT handle EVERYTHING in cluster. kops handles kube-proxy and everything else
in kube-proxy namespace.ONLY Ashish and Klavs can run KOPS (until we find a fix) - on customer
clouds

## ArgoCD CLI

* You can manage applications using argocd cli. Login into argocd server by installing argocd cli on
your system.

* To install ArgoCD CLI use

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

* To do login into argocd via CLI from your local desktop, you can use Kubernetes API server for
authentication. To do so you need to simply log into the desired cluster you are working with via
KubeConfig (at EnableIT we use Teleport to do this securely), then use the following commands

```bash
kubectl config set-context --current --namespace=argocd
argocd login <argocd-server-url> --core
```

and happy hacking! you can modify the ArgoCD resources via argocd CLI itself.

* [HACK] You can also get a shell of argocd server and use argocd inside the pod.
To login into argocd on pod use the following command:

    ```bash
    argocd login <podname>:8080
    ```

    argocd-server-id is the id of argocd server pod. Default port is `8080`.

* If you dont know the admin password for argocd ask the appropriate authority or the reset
it in case it is unretrievable.

### Create argocd token

 It is assumed you have created an user with apikey capabilities. [Link to docs]( https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#:~:text=accounts.alice%3A%20apiKey%2C%20login)

* Get a shell into argocd server pod
* Run the commands

  ```sh
  # login using admin creds
  argocd login <argocd ingress> --username admin --password <admin password>

  # List all argocd accounts to make sure the user with apikey capabilities are there
  argocd account list

  # Create a password for that user
  argocd account update-password --account apiuser --current-password <existing admin user password> --new-password <newpassword>

  # Generate the token using user
  argocd account generate-token -a apiuser --server-name <argocd ingress>
  ```

## Create admin password

* Generate a random string

  ```sh
  $ gopass pwgen 50
  SnuTjj4WISX0opUYiGOGLNFq7Ar34uWdhphIVHWORiX7SWOkW9
  ```

* Generate random string for admin password

  ```sh
  $ gopass pwgen 30
  $ bcrypt-tool hash JljJlkjhayZePnRznr4r 10
  ```

* Create the secret

  ```sh
  kubectl create secret generic argocd-secret --namespace argocd --dry-run=client --from-literal=admin.password='$2a$10$nOZv8mvkEV6' --from-literal=admin.passwordMtime="$(date +%FT%T%Z)" --from-literal=server.secretkey=m5wtVpw9oA --output=yaml | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets -o yaml > argocd-secret.yaml
  ```

* Manually apply, (since you can't sync, ofcourse argocd is down)

  ```sh
  cat argocd-secret.yaml | kubectl apply -f -
  ```

* Delete the argocd-server pod (so deployment can re-create it again)

* Sync the sealed-secret in the secret app via argocd, since it matches up againt the git

## Replace admin password

* Run our script to do this:
  Source: https://github.com/argoproj/argo-cd/blob/master/docs/faq.md#i-forgot-the-admin-password-how-do-i-reset-it

  NB. SPACE in front of 'bcrypt-tool' command IS IMPORTANT - as it ensures its NOT stored in your bash history

  ```sh
  # sudo snap install bcrypt-tool

  # <need-space> bcrypt-tool hash "lolyourpassword123" 10

  # kubectl -n argocd patch secret argocd-secret -p '{"stringData": { "admin.password": "<insert-bcrypt-hash>", "admin.passwordMtime": "'$(date +%FT%T%Z)'" }}'
  ```

  and KILL the pod(s) called `argo-cd-argocd-server-*`

## Adding new/switching git repos for applications

### Add Argocd repos

* Before you attempt to add any new repos to ArgoCD, make sure you have both `yq` and the `kubeseal` client installed:

```sh
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/kubeseal-0.18.0-linux-amd64.tar.gz
tar xfz kubeseal-0.18.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

```sh
snap install yq
```

or (`wget` alternative for `yq`)

```sh
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - |\
  tar xz && mv ${BINARY} /usr/bin/yq
```

* ArgoCD requires 1 secret per repo it needs to connect to.

* Create a secret `argocdrepo-myreponame.yaml` inside the `sealed-secrets/argocd` directory of your KubeAid config repo.

* You can refer to the [sealed-secrets README](../sealed-secrets/README.md) for more info and a template you can use.

* Generate sealedsecret by running following command

```bash
kubectl create secret generic repo-token-name --namespace argocd --dry-run=client --from-literal=type='git' --from-literal=name='repo-token-name' --from-literal=url='https://gitea.obmondo.com/EnableIT/repo-name.git' --from-literal=username='enableit_bot' --from-literal=password='SECRETPASSWORD' --output yaml | yq eval '.metadata.labels.["argocd.argoproj.io/secret-type"]="repository"' - | yq eval '.metadata.annotations.["sealedsecrets.bitnami.com/managed"]="true"' - | yq eval '.metadata.annotations.["managed-by"]="argocd.argoproj.io"' - | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml - > repo-token-name.yaml
```

* Apply the secret in the `argocd` namespace of your cluster:

```sh
kubectl apply -f argocdrepo-myreponame.yaml -n argocd
```

* Once the secret is applied it will sync automatically.

* You can confirm the process was successful by navigating to the ArgoCD UI -> Settings -> Repositories.

* `CONNECTION STATUS` should be `Successful`.

### Switching source repos for your apps

* Now you can switch the sources of any app in your cluster to use the newly-added repo instead.

* You can do this by navigating to any of your root app's pages on ArgoCD's UI.

* `APP DETAILS` -> `MANIFEST` and replacing the old repo's URL and other data with the new one's.

* If your app is single-source, you can edit the source repo directly from the `SUMMARY` tab.

* Re-sync the app to apply the changes.

## Argocd status stuck in Progressing

* The argocd application in ArgoCD UI remains stuck in Progressing state.

  As per argocd faq, the issue is from Traefik and a few other ingress controllers.
  https://github.com/traefik/traefik/issues/3377
  https://argo-cd.readthedocs.io/en/stable/faq/

  The `status.loadBalancer` field is empty for the argocd ingress, and it seems to be the core reason for this issue.

  ```sh
  kubectl -n argocd get ing argo-cd-argocd-server -o jsonpath={.status}
  ```

## Upgrading Argocd

* For updating the Argocd application through helm check the document for [Updating helm repository](../../bin/README.md)
* In latest version of Argocd You can provide multiple sources using the sources field.
* You can use `sources` parameters for adding Helm value files from an external Git repository [Ref Link](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/#helm-value-files-from-external-git-repository)
* To test the updated changes on argocd you can change the targetRevision from HEAD your updated branch and test it.
* Try checking the AppDiff if the changes seem to be fine then you can sync the application.
* The application would require hard refresh to get the application up.
* Once the Changes seem fine you can sync the application.
* After syncing the application check on k9s your pod will be recreated.
* Try logging to the argocd panel in the new browser and check the version it will be updated.

## Error shown while updating argocd

`1.` **spec.source.repoURL and spec.source.path either spec.source.chart are required**

* Check the crd changes have applied to the new version.
* You can manually apply the changes for application crd by `kubectl apply -f application-crd.yaml`
* If that doesn't work you can apply on server-side `kubectl apply -f application-crd.yaml --server-side`
* Don't try to delete the crd assuming that the argocd will generate the new updated one.
* It led to delete most of the running applications on argocd and the argocd will be broken.

`2.` **ComparisonError: groupVersion shouldn't be empty**

* This Error shows for using incorrect ApiVersion. This can be identified by checking the apiversion in the template files.
* In Argocd the first application in root will be showing this error. so that application has the wrong ApiVersion.

## Configure argocd with keycloak

* Upstream doc: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/#keycloak-and-argocd-with-pkce

  - Follow upstream doc - for setting up keycloak client and groups
    NB. You must choose the realm your users are in - NOT master realm.
  - add 'your version of this' - to argocd values file,under argocd.configs:
  ```
      rbac:
      policy.csv: |
        g, ArgoCDAdmins, role:admin
        g, ArgoCDDevs, role:readonly
      scopes: '[groups, email]'
    cm:
      oidc.config: |
        name: Keycloak
        issuer: https://keycloak.obmondo.com/auth/realms/Obmondo
        clientID: argocd
        clientSecret: $oidc.keycloak.clientSecret
        requestedScopes: ["openid", "profile", "email", "groups"]
  ```
  - update/create argocd-secret
  ```sh
  bcrypt-tool hash "lolpassword" 10

  # When creating a new argocd-secret
  kubectl create secret generic argocd-secret --namespace argocd --dry-run=client --from-literal=admin.password='crypt-output-from-above-command' --from-literal=admin.passwordMtime="$(date +%FT%T%Z)" --from-literal=oidc.keycloak.clientSecret='you-get-from-keycloak' --from-literal=server.secretkey='any-random-string-which-is-long-enough' --output=yaml | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets -o yaml - > argocd-secret.yaml

  # When updating the existing argocd-secret
  kubectl create secret generic argocd-secret --namespace argocd --dry-run=client --from-literal=oidc.keycloak.clientSecret="you-get-from-keycloak" -o yaml| kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml --merge-into argocd-secret.yaml
  ```

  ```raw
  * To add any new user into argocd as an admin
    login to keycloak
    -> Users
    -> Select User
    -> Under `groups` tab
    -> Select the required group (See values for argocd https://<kubeaid-config-repo-url>/-/blob/main/k8s/<clustername>/argocd-apps/values-argo-cd.yaml under policy.csv)
    -> done
  ```

## Troubleshooting ArgoCD and Keycloak

* Check whether there is a secret called `argocd-secret` in the `argocd` namespace in the k8s cluster.
* The `argocd-secret` should have a key `oidc.keycloak.clientSecret`.
* Verify your keycloak user roles and group memberships for your username by logging into the keycloak server from UI.
* The URL for keycloak server would be https://keycloak.your.domain.com. Refer [Keycloak readme](../keycloak/README.md).
* Check the `values-argo-cd.yaml` in the kubeaid-config repo for the k8s cluster. Match policy.csv with the roles in Keycloak

## Development with ArgoCD and Helm chart

To create a new application in ArgoCD using a Helm chart, we need to go through the following

* Checkout a new feature branch from main branch of kubeaid repo
* Create a folder inside `argocd-helm-charts` folder in the kubeaid repo (or the kubernetes-config-enableit repo)
* Add your helm chart files inside the folder - e.g. Chart.yaml, values.yaml, etc
* Using `helm template` command, verify the objects that would be created in the cluster
* Execute `bin/helm-repo-update.sh` from the kubeaid repo to update the dependencies for the Helm chart.
* If the objects are being generated correctly, then push the changes to the feature branch and create a Merge Request
* To create a new application in ArgoCD (till v2.3), create a values-appName.yaml and templates/appName.yaml
in the respective customer's kubeaid-config repo.
* Add the above config related changes to a new branch and do an MR on the config repo.
* Sync the root app in ArgoCD. AgroCD will create the application and it would show up as `Out of Sync`.
* Sync the app so that ArgoCD fetches the files from the Helm chart and runs `helm template`. The yaml output of
the command is sent to the k8s api to create the objects accordingly in the cluster.
* Once the objects have been created, the app would be in `Healthy` state.
* To make and test further changes, change the values in the Helm chart. Test using `helm template` as mentioned
earlier and push the changes to feature branch. Sync the app again from ArgoCD to apply the changes.

Link to detailed workflow : https://gitlab.enableit.dk/kubernetes/kubeaid/-/blob/master/argocd-helm-charts/readme.md

## Links

* Full docs on ArgoCD - see doc on Application CRD f.ex.
https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications
* ArgoCD application CRD spec - incl. description for every field:
https://github.com/argoproj/argo-cd/blob/master/manifests/crds/application-crd.yaml
* Article on devops and Argocd advanced usage
https://itnext.io/level-up-your-argo-cd-game-with-applicationset-ccd874977c4c

# CircleCI Runner

NOTE: there is no helm package given by the upstream guys, so have build it by forking it under Obmondo org
so you can download the chart under main branch and a PR is also raised https://github.com/CircleCI-Public/circleci-runner-k8s/pull/11/files
this is just a workaround, if you need to change anything in the helm chart, just push it to the main branch of
Obmondo fork.

## CircleCI CLI Setup

* Install cli https://circleci.com/docs/2.0/local-cli/index.html#installation
* Need github organisation admin, you can create here [API Personal Token](https://circleci.com/docs/2.0/managing-api-tokens/#creating-a-personal-api-token)
  NOTE: The project api token didn't worked and end up authentication issue when creating a namespace in circleci,
        so watchout for that

```sh
# sudo snap install circleci

# circleci setup

# circleci namespace create ci-feature-branch-deployment github <customer_name>
You are creating a namespace called "ci-feature-branch-deployment".

This is the only namespace permitted for your github organization, <customer_name>.

To change the namespace, you will have to contact CircleCI customer support.

? Are you sure you wish to create the namespace: `ci-feature-branch-deployment` Yes
Namespace `ci-feature-branch-deployment` created.
Please note that any orbs you publish in this namespace are open orbs and are world-readable.

#  circleci runner resource-class create ci-feature-branch-deployment/testing01 testing-circleci-cd --generate-token
If you have not already agreed to Runner Terms in a signed Order, then by continuing to install Runner, you are agreeing to CircleCI's Runner Terms which are found at: https://circleci.com/legal/runner-terms/.
If you already agreed to Runner Terms in a signed Order, the Runner Terms in the signed Order supersede the Runner Terms in the web address above.
If you did not already agree to Runner Terms through a signed Order and do not agree to the Runner Terms in the web address above, please do not install or use Runner.

api:
    auth_token: xxx
+----------------------------------------+---------------------+
|             RESOURCE CLASS             |     DESCRIPTION     |
+----------------------------------------+---------------------+
| ci-feature-branch-deployment/testing01 | testing-circleci-cd |
+----------------------------------------+---------------------+
```

### Create Secret

```sh
kubectl create secret generic circleci-runner-token -n circleci --dry-run=client --from-literal=resourceClass=ci-feature-branch-deployment/testing01 --from-literal=runnerToken=xxxx -o yaml | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets --cert /tmp/staging.pem -o yaml - > /tmp/circleci-runner-token.yaml
```

### Create KUBECONFIG

NOTE: This is using **circleci-runner** serviceaccount and namespace, so if you change the default values,
      make sure you change the command line thereupon.

```sh
# Save the CA cert
# kubectl get secret $(kubectl get serviceaccount circleci-runner -n circleci-runner -o yaml | yq eval '.secrets.[].name' -) -n circleci-runner -o yaml | yq eval '.data."ca.crt"' - | base64 --decode > /tmp/staging.ca.crt
```

```sh
# Add the cluster in the config file
# kubectl config --kubeconfig /tmp/kube.config set-cluster your-clustername --embed-certs=true --server="https://kubernetes.default.svc" --certificate-authority=/tmp/staging.ca.crt
```

```sh
# Add the credentials for the circleci-runner serviceaccount
# kubectl config --kubeconfig /tmp/kube.config set-credentials circleci-runner --token=$(kubectl get secret $(kubectl get serviceaccount circleci-runner -n circleci-runner -o yaml | yq eval '.secrets.[].name' -) -n circleci-runner -o yaml | yq eval '.data."token"' - | base64 --decode)
```

```sh
# Add the context
# kubectl config --kubeconfig /tmp/kube.config set-context your-clustername --cluster=your-clustername --user=circleci-runner
```

```sh
# Set the current context
# kubectl config --kubeconfig /tmp/kube.config use-context your-clustername
```

```sh
# Create the KUBECONFIG encoded
# cat /tmp/kube.config | base64 --wrap=0
```

### Add Environment variable in CircleCI Project or Organization (You have to take a call here)

* Goto CircleCI dashboard
* Select **Project**
* Select **Project Settings**
* Select **Environment Variables**
* Select **Add Environment Variable**
* Name: KUBECONFIG_DATA
* Value: your base64 encoded of kube.config

### Blogs

* https://medium.com/devopstricks/ci-cd-with-gitlab-kubernetes-399f81ac91ae
* https://blog.lwolf.org/post/how-to-create-ci-cd-pipeline-with-autodeploy-k8s-gitlab-helm/
* https://www.vadosware.io/post/level-one-automated-k8s-deployments-with-gitlab-ci/#step-0-have-a-kubernetes-cluster

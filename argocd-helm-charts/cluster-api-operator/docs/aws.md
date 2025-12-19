# AWS Setup

## Notes

1. Latest version depends on [AMI release](https://cluster-api-aws.sigs.k8s.io/topics/images/built-amis.html)

```sh
clusterawsadm ami list --kubernetes-version v1.28.3 --region eu-west-1 --os ubuntu-20.04
KUBERNETES VERSION   REGION      OS             NAME                                       AMI ID
v1.28.3              eu-west-1   ubuntu-20.04   capa-ami-ubuntu-20.04-v1.28.3-1698915010   ami-03cd26c84ae9a587c
```


## Prequisites

* Download the cli binary to manage cluster on aws

```sh
curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.5.0/clusterawsadm_v2.5.0_linux_amd64 -o clusterawsadm
chmox + clusterawsadm
mv clusterawsadm /usr/local/bin/
clusterawsadm version
```

* Get AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (You can create a new service account)
* Login on AWS console, go to IAM and create User
* export these variables

  ```sh
    export CUSTOMERID=common
    export AWS_REGION=us-east-1
    export AWS_ACCESS_KEY_ID=<your-access-key>
    export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>

    export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
  ```

* Create the required secret and git push and sync it on argocd (mgmt cluster)

  ```sh
  kubectl create secret generic cluster-api-token --dry-run=client --namespace capi-cluster-${CUSTOMERID} --from-literal=AWS_B64ENCODED_CREDENTIALS=${AWS_B64ENCODED_CREDENTIALS} -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --namespace cluster-api -o yaml > capi-cluster-token.yaml
  ```

* Sample [values.yaml](./examples/values-aws.yaml)




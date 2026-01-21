# Harbor

Harbor needs to have a storage-class defined in its values - that gives it a PV with ReadWriteMany support - to ensure High Availability, scaling, failover and drainage of k8s nodes (for regular maintenance) works.

## Extra configurations for complete Harbor setup

We need to create few configurations and save them in secrets.
These are required for Harbor to run the core and jobservice successfully.

1. Create a new password for harbor user

    ```sh
    htpasswd -B -c /tmp/htpasswd harbor_registry_user
    ```

    > NOTE: The default password is `harbor_registry_password`.

2. Generate `16/32` chars passwords

    ```sh
    # 16 chars password
    gopass pwgen 16

    # 32 chars password
    gopass pwgen 32
    ```

3. Generate `harbor-core-custom` secret and apply. cause helm chart generate random passowrd on each helm template
   render. So have a static password encrypted with sealed-secrets, makes argocd diff happy
   NOTE: Remember to restart the core pod after syncing the secret, so core pod can read the new secret
   We can run a hook job to automate this later.

    ```raw
    * Get the CSRF_KEY
    # kubectl get secret -n harbor harbor-core -o yaml | yq '.data.CSRF_KEY' | base64 -d

    * Get the secret
    # kubectl get secret -n harbor harbor-core -o yaml | yq '.data.secret' | base64 -d

    * Get the jobservice secret
    # kubectl get secret -n harbor harbor-jobservice -o yaml | yq '.data.JOBSERVICE_SECRET' | base64 -d

    * Get the harbor-registry secret
    # kubectl get secret -n harbor harbor-registry -o yaml | yq '.data.REGISTRY_HTTP_SECRET' | base64 -d

    * Get the harbor-registry htpasswd secret
    # htpasswd -B -c /tmp/htpasswd harbor_registry_user
    New password:
    Re-type new password:
    Adding password for user harbor_registry_user
    root@caefd85b49a0:~# cat /tmp/htpasswd
    harbor_registry_user:$2y$05$y3dVHpPFgp0kpT3hIwYBl./Zprrn6ZV5fJlAUDImshsz3n9u7gXJK

    * Get the TLS cert and key
    # kubectl get secret -n harbor harbor-core -o yaml | yq '.data."tls.crt"'  | base64 -d > /tmp/tls.crt
    # kubectl get secret -n harbor harbor-core -o yaml | yq '.data."tls.key"'  | base64 -d > /tmp/tls.key

    * Generate the secret
    # NOTE: if you have OIDC client, then add the oidc-config section as well

    # kubectl create secret generic harbor-core-custom \
      --namespace harbor \
      --dry-run=client \
      --from-literal=CSRF_KEY={32 chars password} \
      --from-file=tls.crt=/tmp/tls.crt \
      --from-file=tls.key=/tmp/tls.key \
      --from-literal=secret={16 chars password} \
      --from-literal=JOBSERVICE_SECRET={16 chars password} \
      --from-literal=REGISTRY_HTTP_SECRET={16 chars password} \
      --from-literal=REGISTRY_HTPASSWD="harbor_registry_user":'{harbor registry user password}' \
      --from-literal=REGISTRY_PASSWD=harbor_registry_password \
      --from-literal=oidc-config='{"auth_mode":"oidc_auth","oidc_name":"Obmondo Keycloak","oidc_endpoint":"https://keycloak.example.com/auth/realms/harbor","oidc_client_id":"harbor","oidc_client_secret":"{oidc client secret}","oidc_scope":"openid,profile,email,offline_access","oidc_verify_cert":"true","oidc_auto_onboard":"true","oidc_user_claim":"email","oidc_admin_group":"harborAdmins"}'\
      -o yaml | \
      kubeseal --controller-namespace sealed-secrets \
      --controller-name sealed-secrets-controller \
      --format yaml > harbor-core-custom.yaml
    ```

4. In KeyCloak, create `harborAdmins` group.

> NOTE: You don't need to worry about `HARBOR_ADMIN_PASSWORD` in secrets.
> The updated password configs gets saved directly in the DB. This is a *cough* ~~bug~~ *cough* feature.

## Pushing images to Harbor

Go to the Harbor dashboard and log in. On the top-right side, your name will be present.
Clicking on which you would see the option to access user profile. On user profile, you can copy your CLI secret.
This will act as your registry password. You can save this CLI secret in an environment variable and call it $REGISTRY_PASSWORD.

Now you can login to the registry using buildah or docker. There is a demo below

buildah

```bash
echo $REGISTRY_PASSWORD | buildah login -u <username> --password-stdin <registry_url>
```

docker

```bash
docker login <registry_url>
```

You can build the container and push it using either docker or buildah using following commands

buildah

```bash
buildah bud -t "<registry_url>/<project_name>/<image_name>:<tag>" .
CONTAINER_ID=$(buildah from --pull=false "<registry_url>/<project_name>/<image_name>:<tag>") # not necessary
buildah commit --squash "$CONTAINER_ID" "<registry_url>/<project_name>/<image_name>:<tag>" # not necessary
buildah push "<registry_url>/<project_name>/<image_name>:<tag>"
```

docker

```bash
docker build -t "<registry_url>/<project_name>/<image_name>:<tag>" .
docker push "<registry_url>/<project_name>/<image_name>:<tag>"
```

## Giving Image Push Access

Harbor allows role based access management. To give an user some specific perms, you need to go to harbor.
In the Projects dashboard, go to the particular project name.
Add user and select group that needs to be assigned to that particular user.
Here is a link that elaborately explains what roles gives what permission to a particular user - https://goharbor.io/docs/2.1.0/administration/managing-users/user-permissions-by-role/

## Debugging Harbor OIDC Issues

Sometimes, when the changes related to your OIDC provider is done in Harbor, it starts throwing errors which goes like

```bash
failed to create user record: user Sanskar_Bhushan or email sanskar@obmondo.com already exists
```

To fix this issue you should log into the KBM cluster and run the following commands to find Harbor Postgres database

```bash
kubectl get all -n harbor
```

After running the above given command you should be able to see an output similiar to the one given below

```bash
sbdtu5498@sbdtu5498-TUF-Gaming-FX505DT-FX505DT:~$ kubectl get all -n harbor
NAME                                     READY   STATUS    RESTARTS      AGE
pod/harbor-core-5d584bc446-whw5w         1/1     Running   0             27m
pod/harbor-database-0                    1/1     Running   0             24h
pod/harbor-jobservice-5d64b4956f-h2pd4   1/1     Running   2 (46h ago)   46h
pod/harbor-portal-795cc5d55d-snh4d       1/1     Running   0             46h
pod/harbor-redis-0                       1/1     Running   0             46h
pod/harbor-registry-756bd69496-fxf9w     2/2     Running   0             46h
pod/harbor-trivy-0                       1/1     Running   0             46h

NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/harbor-core         ClusterIP   10.111.169.192   <none>        80/TCP              2d17h
service/harbor-database     ClusterIP   10.99.219.128    <none>        5432/TCP            5d19h
service/harbor-jobservice   ClusterIP   10.96.13.222     <none>        80/TCP              2d17h
service/harbor-portal       ClusterIP   10.104.115.157   <none>        80/TCP              2d17h
service/harbor-redis        ClusterIP   10.105.81.73     <none>        6379/TCP            2d17h
service/harbor-registry     ClusterIP   10.103.190.151   <none>        5000/TCP,8080/TCP   2d17h
service/harbor-trivy        ClusterIP   10.96.165.179    <none>        8080/TCP            2d17h

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/harbor-core         1/1     1            1           46h
deployment.apps/harbor-jobservice   1/1     1            1           46h
deployment.apps/harbor-portal       1/1     1            1           46h
deployment.apps/harbor-registry     1/1     1            1           46h

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/harbor-core-5d584bc446         1         1         1       46h
replicaset.apps/harbor-jobservice-5d64b4956f   1         1         1       46h
replicaset.apps/harbor-portal-795cc5d55d       1         1         1       46h
replicaset.apps/harbor-registry-756bd69496     1         1         1       46h

NAME                               READY   AGE
statefulset.apps/harbor-database   1/1     24h
statefulset.apps/harbor-redis      1/1     46h
statefulset.apps/harbor-trivy      1/1     46h
```

Now we need to get inside the pod corresponding to the 'harbor-database' stateful set using the following command

```bash
kubectl exec -it pod/harbor-database-0 -n harbor -- /bin/bash
```

After getting inside the pod, you would be able to access the Postgres container.
Thus would be able to perform operations manually on the database.
In order to access the database corresponding to the Harbor registry, run the command

```bash
psql -U postgres -d registry
```

In order to get get the user record, run the command

```sql
select * from harbor_user;
```

### Accessing Harbor admin dashboard

In order to access Harbor admin dashboard we first need to reset the existing Harbor password from inside the database

```sql
update harbor_user set salt='', password='' where user_id = 1;
```

This will reset the Harbor admin credential to its initial form. Now exit the database and the Postgres pod using the commands

```bash
\q
exit
```

Restart the Harbor core pod by deleting the pod and replicaset will take care of restarting the pod again

```bash
kubectl delete pod -n harbor -l component=core
```

Once the pod is restarted then enter inside the restarted pod using the following command

```bash
kubectl exec -it pod/harbor-core-5d584bc446-whw5w -n harbor -- /bin/bash
```

After getting inside the pod, access the admin credentials using the following command

```bash
env | grep -i admin
```

Use the username 'admin' and the found out credential to log into the Harbor as an admin.
Then you can manually delete the older users from there which will fix the persisting issue.

### Deleting existing users directly via database

After running this command you would be able to get a list of all the Harbor users.
Now in order to fix the persisting issue, you simply delete all the older users and this issue will be fixed.
Before manually performing any operations on Database, always consult your senior.
It may have unwanted consequences and you might lose your data.

## Debugging Harbor State Mismatch Issues

This issue generally persists because of bad caches that leads to troubles.
In order to fix this issue you simply need to delete all the existing Harbor deployment and statefulsets.
Resync them using Argo CD that will lead to a complete clean-up of all the previous session cache.
Thi will help you get rid of this issue.

## Clean Up of Harbour

When you delete images from Harbor, the space isn't automatically reclaimed.
To free up space, you need to perform garbage collection, which removes unreferenced blobs from the file system.

**Note**: You need admin privileges for running Garbage Collection.

### Running Garbage Collection

1. **Log** in: Access the Harbor interface with a system administrator account.
2. **Navigate**: Go to `Administration` > `Garbage Collection` > `Garbage Collection` tab.
3. **Options**:
   - To remove untagged artifacts, check the `Delete Untagged Artifacts` box.
   - To start garbage collection, click `GC Now`.

**Note**: During garbage collection, Harbor enters read-only mode, preventing any modifications to the registry.
The `GC Now` button is limited to being used once per minute to prevent frequent triggering.

### Scheduling Garbage Collection

1. **Navigate**: Go to `Administration` > `Garbage Collection` > `Garbage Collection` tab.
2. **Schedule**: Click Edit and choose the frequency from the drop-down menu:
    - `None`: No scheduled garbage collection.
    - `Hourly`: Every hour at the beginning.
    - `Daily`: Every day at midnight.
    - `Weekly`: Every Saturday at midnight.
    - `Custom`: Set a custom schedule using a cron job.
3. **Options**: To remove untagged artifacts, check the Delete Untagged Artifacts box.
4. **Save**: Click `Save`.

### Viewing Garbage Collection History

1. **History**: Go to the `History` tab to see the records of the 10 most recent garbage collection runs.
2. **Logs**: Click the icon in the `Logs` column to view the logs for a specific garbage collection job.

### Log Deletion

1. **Log Retention**: By default, Harbor retains GC logs. However, you may need to delete old logs to free up space.
2. **Navigate**: Go to `Administration` > `Garbage Collection` > `History` tab.
3. **Delete Logs**: Select the logs you wish to delete and click the `Delete` button.
4. **Confirm**: Confirm the deletion to remove the selected logs from the system.

By managing garbage collection and log deletion, you can maintain optimal storage space and system performance in Harbor.

For more Detailed information you can also checkout - [Harbor Doc](https://goharbor.io/docs/2.0.0/administration/garbage-collection/)

## Multi Platform Images

We're using [Docker build action](https://github.com/docker/build-push-action) to create container images.
These support multi-platform image generation.

### Building Multi Platform Images

Specify for which platforms you want to build image in `platforms` workflow input.
If specifying multiple platforms, use `,` as separator, and NOT space.

### Verify Multi Platform Images

You can check if the image has multi-platform layers using docker buildx.

```sh
docker buildx imagetools inspect harbor.obmondo.com/obmondo/obmondo-k8s-agent:v1.1.6
```

Multi-platform images has the information about supported multiple platforms in manifest.

### Push Multi-Platform Images to Another Registry

We usually do this for `obmondo-k8s-agent` to upload from Harbor registry to GitHub registry.

```sh
docker buildx imagetools create --tag ghcr.io/obmondo/obmondo-k8s-agent:v1.1.6 harbor.obmondo.com/obmondo/obmondo-k8s-agent:v1.1.6
```

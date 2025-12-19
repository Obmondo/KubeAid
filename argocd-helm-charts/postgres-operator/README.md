# Postgres-operator

## Summary

Postgres-operator is used to manage Postgres instances, including high-availability setups with master and
multiple slaves, and automatic failover and backups of data to offsite location.

Example [postgres-cluster](./examples/postgres-cluster.yaml)

### how to setup a postgresql cluster instance on diff providers

* [AWS](./examples/aws.yaml)
* Setup the values files for baremetal server
  NOTE: currently its not possible to setup the secret directly in postgres operator which will pass
  the env variable to backup pods. [More info](https://github.com/zalando/postgres-operator/pull/2097)
  * [Physical](./examples/baremetal.yaml)
  * Create the secret for accessing self-hosted s3

  ```sh
  kubectl create secret generic $postgres-cluster-name-postgres-pod-env -n $namspace-where-is-your-postgres-cluster-deployed --dry-run=client --from-literal=AWS_SECRET_ACCESS_KEY=boolol -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller -o yaml > /path/to/sealed-secret/dir/$postgres-cluster-postgres-pod-env.yaml
  ```

  * Setup the s3 profile

  ```raw
  # cat ~/.aws/config
  [profile obmondo] -> you can give any name to your profile
  region = us-east-1
  ```

  ```raw
  # cat ~/.aws/credentials
  [obmondo]
  aws_access_key_id = your_key_id
  aws_secret_access_key = your_secret_key
  ```

  ```sh
  export AWS_PROFILE=obmondo
  ```

  * Create the bucket manually

  ```sh
  # aws s3api create-bucket --bucket kbm-postgres-buckets --region eu-west-1 --endpoint-url=https://s3.obmondo.com
  {
    "Location": "/kbm-postgres-buckets"
  }

  # aws s3api list-buckets --region eu-west-1 --endpoint-url=https://s3.obmondo.com
  ```

  * Add the secret in the respective values files

  ```yaml
  postgresql:
    access_secret: keycloakx-pgsql-postgres-pod-env
  ```

  * The postgres cluster pod should be restarted, if not you can safely reboot the secondary node

  ```sh
  envdir "/run/etc/wal-e.d/env" wal-g backup-list
  ```

  * To start a manual backup, get a shell access to postgres cluster pod, [more info](https://postgres-operator.readthedocs.io/en/latest/administrator/#wal-archiving-and-physical-basebackups)

  ```sh
  su - postgres
  envdir "/run/etc/wal-e.d/env" /scripts/postgres_backup.sh "/home/postgres/pgdata/pgroot/data"
  ```

## Troubleshooting

* `PersistentVolume is filling up`
  or
  `FATAL:  could not write lock file "postmaster.pid": No space left on device`

  * Increase the [volume size](https://postgres-operator.readthedocs.io/en/latest/user/#increase-volume-size)

## Notes

* Depending on the chart please check what database env variables are getting used. And provide those values through
[values.yaml](../keycloak/values.yaml).

* Create the `postgresql.yaml` file in `templates` directory of umbrella chart.
So that postgres-operator will use that to manage the instance

* Also check this [example](../keycloak/templates/postgresql.yaml) for postgresql.yaml file

* Also check example of mattermost setup for [postgresql](../mattermost-team-edition/templates/postgresql.yaml) and the corresponding

* [values.yaml](../mattermost-team-edition/values.yaml) file

## Backup

CronJobs for postgresql logical backup cronjob template can be found [here](./examples/backup-template/postgresql-logical-backup.yaml).

## Restore Postgres DB using pg dump

1. change the DELETE to RETAIN on pv (find pv from the respective pvc)
2. Delete the claim reference from the above pv
3. run a test pod

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: ubuntu
    spec:
      containers:
      - name: jammy
        image: docker.io/ubuntu:jammy
        command: ["/bin/sleep", "7d"]
        imagePullPolicy: IfNotPresent
        env:
        volumeMounts:
          - mountPath: /var/tmp
            name: pgdata
      restartPolicy: Always
      volumes:
        - name: pgdata
          persistentVolumeClaim:
            claimName: pgdata-mattermost-pgsql-1
    ```

4. Copy date from mountpath to your local system

    ```shell
    # Here the test pod ubuntu is running in mattermost namespace
    kubectl cp mattermost/ubuntu:/var/tmp/pgroot .
    ```

5. change the postgresql.conf (on your local system, wherever you have copied)
    and change the lines as below.

    ```text

    #extwlist.custom_path
    #extwlist.extensions

    shared_preload_libraries = 'pg_stat_statements'

    hba_file = '/var/lib/postgresql/data/pg_hba.conf'
    ident_file = '/var/lib/postgresql/data/pg_ident.conf'
    #recovery_target = ''
    #recovery_target_lsn = ''
    #recovery_target_name = ''
    #recovery_target_time = ''
    #recovery_target_timeline = 'latest'
    #recovery_target_xid = ''
    #restore_command = 'envdir "/run/etc/wal-e.d/env" timeout "0" /scripts/restore_command.sh "%f" "%p"'
    ```

6. Generate a dummy cert and copy it into the `/pgroot/data`

    ```shell
    # command to generate a dummy cert
    openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout server.key -out server.crt
    ```

7. Run the postgresql docker image with the data copied from the pv

    ```shell
    docker run  -d --name=postgres -e POSTGRES_PASSWORD=mysecret -e PGDATA=/var/lib/postgresql/data -e POSTGRES_USER=postgres  -v /home/ashish/playground/mattermost-01/pgroot/data:/var/lib/postgresql/data postgres:12 -c ssl=on -c ssl_cert_file=/var/lib/postgresql/data/server.crt -c ssl_key_file=/var/lib/postgresql/data/server.key
    ```

    Upon successful start of the postgresql docker container, export the data from the container
    and import it into a new postgres-operator instance.

    ```shell
    # This will export the data from the docker container
    docker exec -it postgres pg_dump -c -U mattermost > backup.sql

    # This would copy the backup.sql to the mattermost-pgsql-0 instance
    kubectl cp backup.sql mattermost/mattermost-pgsql-0:/home/postgres/pgdata
    ```

8. Drop the existing DB from the psql instance and import the data from the `backup.sql`
    Make sure mattermost-teams pods is not running otherwise it will not allow you to remove the db
    from the psql instance.

    ```shell
    kubectl exec -n mattermost -it mattermost-pgsql-0 -- su postgres
    psql -d mattermost < backup.sql
    ```

## Restore Postgres DB using WALG from s3

1. Get clone time stamp run the command `cat postres.yaml.matter | kubectl apply -n mattermost -f -`
  on the yaml file below

  ```yaml
  # Here we are restoring the keycloakx-pgsql instance

  apiVersion: acid.zalan.do/v1
  kind: postgresql
  metadata:
    name: keycloakx-pgsql
    labels:
      velero.io/exclude-from-backup: "true"
  spec:
  env:
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: keycloakx-pgsql-postgres-pod-env
        key: AWS_SECRET_ACCESS_KEY
  - name: CLONE_USE_WALG_RESTORE
    value: "true"
  - name: CLONE_AWS_REGION
    value: eu-west-1
  - name: CLONE_AWS_ACCESS_KEY_ID
    value: kcm
  - name: CLONE_AWS_SECRET_ACCESS_KEY
    value: xxxxxx123
  - name: CLONE_METHOD
    value: CLONE_WITH_WALG
  - name: CLONE_AWS_ENDPOINT
    value: https://s3.obmondo.com
  - name: CLONE_WAL_S3_BUCKET
    value: kcm-postgres-backups
  - name: CLONE_WALG_BUCKET_SCOPE_SUFFIX
  - name: CLONE_TARGET_TIME
    value: "2023-02-07T10:02:12+00:00"
  - name: CLONE_SCOPE
    value: keycloakx-pgsql
  databases:
    keycloakx: keycloakx
  preparedDatabases:
    keycloakx: {}
  enableMasterLoadBalancer: false
  numberOfInstances: 1
  postgresql:
    version: "12"
  teamId: keycloakx
  users:
    keycloakx:
    - superuser
  clone:
    cluster: "keycloakx-pgsql"  # Inplace restore when having the same cluster name as the source
    timestamp: "2023-02-07T10:02:12+00:00"  # timezone required (offset relative to UTC, see RFC 3339 section 5.6)
  volume:
    size: 8Gi
  ```

  Run a fresh postgres cluster and run this on the new postgres instance

  ```shell
  envdir "/run/etc/wal-e.d/env" wal-g backup-list
  ```

  Remove the cluster that you have installed and the data will be recovered from the s3 bucket

## Restore logical dump made by postgres-operator

* The automatic logical dumps made by postgres-operator use `pg_dumpall` to generate a dump. This is different
  from `pg_dump` because it generates a dump of postgres not a single database. It includes postgres permissions,
  users, all databases, and more items. However when restoring we just need a single database, not the
    entire state of postgres.

1. Download and extract a logical dump Ex: timestamp.sql.gz made by postgres-operator from the s3 bucket to local.
2. Copy this to your database instance in Kubernetes and restore.

      ```shell
      kubectl cp mattermost_dump.sql.gz mattermost/mattermost-pgsql-0:/home/postgres/pgdata
      # Extract the file
      gzip -d mattermost_dump.sql.gz
      psql --host=localhost --port=5432 --username=postgres --password --dbname=mattermost < mattermost_dump.sql
      ```

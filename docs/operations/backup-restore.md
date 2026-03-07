# Backup and Restore Strategy Overview

This document provides a technical overview of the backup mechanisms implemented across Kubernetes clusters managed by our DevOps team.

---

## 1. Persistent Volume (PV) Backup and Restore with Velero

We use Velero to orchestrate backups of Persistent Volume Claims (PVCs) in Kubernetes.

- [Triggering manual backups using existing schedule](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/velero/README.md#triggering-manual-backups)
- [Restoring from backups](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/velero/README.md#restoring-using-existing-backups)
---

## 2. Sealed Secrets Key Backups

- To preserve the ability to decrypt sealed secrets, we automate the backup of the controller’s private key.
- [Backup and Restore documentation](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/sealed-secrets/README.md#how-to-backup-and-restore-sealed-secrets)
---

## 3. Logical Database Backups

We use logical dumps for databases such as PostgreSQL and MongoDB to ensure portability and integrity.

### PostgreSQL
  
- [CNPG backup and restore documentation](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/cloudnative-pg/readme.md#backup-and-recovery)
- [Zalando postgres operator backup and restore documentation](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/postgres-operator/README.md#backup)

### MongoDB

- [Backup and Restore documentation](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/mongodb-operator/Readme.md#backup-and-restore)

## Summary

| Component           | Tool/Method            | Target Storage   |
|---------------------|------------------------|------------------|
| PVCs                | Velero + CSI Snapshots | Azure Blob / S3 Compatible Storage | 
| Sealed Secret Keys  | CronJob + GZIP         | Azure Blob / S3 Compatible Storage |
| PostgreSQL / MongoDB| Logical dump scripts   | Azure Blob / S3 Compatible Storage |

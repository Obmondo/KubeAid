# Azure Prerequisites

## System Requirements
A Linux or MacOS computer with at least 16GB of RAM (8GB might work but may encounter Out of memory (OOM) issues).

## Service Principal
[Register an application (Service Principal) in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app).

## SSH Keypairs

### OpenSSH Keypair
For SSH access to VMs. You can generate this using:

```bash
ssh-keygen -t ed25519 -f azure-ssh-key -C "azure-cluster-key"
```

### PEM Format Keypair
Required for [Azure Workload Identity setup](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster). You can generate this using:

```bash
openssl genpkey -algorithm ed25519 -out jwt-signing-key.pem
openssl pkey -in jwt-signing-key.pem -pubout -out jwt-signing-pub.pem
```

> [!NOTE]
> ed25519 keys are shorter and more secure than RSA keys, though not quantum-safe. If RSA is preferred by you or your organization, use `ssh-keygen -t rsa -b 4096` and `openssl genrsa -out jwt-signing-key.pem 4096` instead.

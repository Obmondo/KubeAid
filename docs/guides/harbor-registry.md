# Host your own central registry with KubeAid


Harbor is an open-source container registry that serves as a robust alternative to paid offerings like DockerHub Business, AWS Elastic Container Registry (ECR), and others. 
It provides a secure, scalable, and feature-rich solution for hosting container images on-premises, giving you full control over your data without storage or access limits.

At Obmondo, we rely on Harbor as the central registry for all our build artifacts, container images, and CI/CD operations. 
Hosting our own registry enhances security, improves performance, and reduces reliance on third-party services.

If you're new to KubeAid, check out our [README](https://github.com/Obmondo/KubeAid/blob/main/README.md).


## Deploying Harbor with KubeAid

- `argocd-apps/templates/harbor.yaml`: This is a template for ArgoCD application. Click [here](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/harbor/example/argocd-apps/templates/harbor.yaml)
- `argocd-apps/values-harbor.yaml`: This file lets you customize Harbor template file using values. Click [here](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/harbor/example/argocd-apps/values-harbor.yaml)

Deployment Steps:
1. Modify the Harbor template to fit your environment (e.g., sources, destinations, etc.).
2. Update the values file with your specific configurations.
3. Push the changes to your kubeaid-config repository.
4. Sync the changes in ArgoCD root application, you can choose to just sync your harbor application as well
5. Now you will have harbor set up successfully. you can refer to our configuration guide for various actions
   With these steps, Harbor will be up and running, 

You can set up keycloak for authentication using our Keycloak [guide](#) 


## Using CLI Tools with Harbor

Once Harbor is deployed, Tools like Docker CLI, Podman can be used to push/pull images. Below are common commands:

### 1. Login to Harbor

```bash
docker login <your-harbor-domain>
```

Example:

```bash
docker login harbor.example.com
```

You’ll be prompted for your username and password.

---

### 2. Tag a Local Image

```bash
docker tag my-app:latest <your-harbor-domain>/demo/my-app:latest
```

Example:

```bash
docker tag my-app:latest harbor.example.com/demo/my-app:latest
```

---

### 3. Push Image to Harbor

```bash
docker push <your-harbor-domain>/demo/my-app:latest
```

---

### 4. Pull Image from Harbor

```bash
docker pull <your-harbor-domain>/demo/my-app:latest
```

---

### 5. List Local Docker Images

```bash
docker images
```

---

### 6. Remove Local Image

```bash
docker rmi <your-harbor-domain>/demo/my-app:latest
```


---

## CI/CD with Harbor and KubeAid

At Obmondo, we integrate Harbor into our CI/CD pipelines using Gitea runner. Here's a sample workflow:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]

jobs:
  build-pull-request:
  runs-on: [server-name]
  needs: [ci]
  uses: []
  with:
    push: true
    file: ./Dockerfile
    tags: harbor.example.com/organization/project-name:${{ gitea.event.number }}
  secrets:
    username: ${{ secrets.HARBOR_USERNAME }}
    password: ${{ secrets.HARBOR_PASSWORD }}
    
  some-other-action:
    runs-on: [server-name]
    container:
      image: harbor.organization.com/organization/project-name:version
```


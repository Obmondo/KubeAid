# Cert-Manager Helm Chart

This Helm chart deploys cert-manager with configurable certificate issuers for automatic SSL certificate management in Kubernetes.

## Features

- **Multiple Issuer Support**: Let's Encrypt (production/staging), Step CA, self-signed
- **Challenge Solvers**: HTTP01 and DNS01 (Cloudflare, Route53)
- **Network Policies**: Optional security policies
- **Monitoring**: Prometheus metrics and ServiceMonitor
- **Flexible Configuration**: Comprehensive values file with examples

## Quick Start

1. **Configure values**: Copy an example from `examples/` directory:
   - **Let's Encrypt**: Copy `values-letsencrypt-example.yaml` (or `values-http.yaml` for a minimal setup) and update email/secret
   - **Step CA**: Use the dedicated `argocd-helm-charts/step-ca/examples/values.yaml`
   - **DNS01**: Copy `values-cloudflare.yaml` or `values-route53.yaml`
2. **Deploy**: Use ArgoCD or Helm to deploy the chart
3. **Verify**: Check ClusterIssuer status and certificate creation

## Certificate Issuer Configuration

Each certificate issuer is added by its own helm chart. "step-ca" runs via the dedicated `argocd-helm-charts/step-ca` chart (see `step-ca/examples/values.yaml`). For other issuers like Let's Encrypt, we use the ClusterIssuer template in `templates/clusterissuer.yaml` (see example in `examples/values-letsencrypt-example.yaml`).

### Supported Issuer Types

#### Let's Encrypt (ACME)
- **Production**: Real certificates for production use
- **Staging**: Test certificates (no rate limits)
- **HTTP01**: Web server challenge
- **DNS01**: DNS challenge for wildcard certificates

#### Step CA
- Internal CA for development and testing
- Custom CA bundle configuration
- Suitable for private/internal domains

#### Self-Signed
- For testing purposes only
- No external dependencies

### Configuration Examples

#### Let's Encrypt Production
```yaml
issuer:
  name: letsencrypt-prod
  enabled: true
  production: true
  issuerEmail: admin@yourdomain.com
  secret: letsencrypt-prod-private-key
  solvers:
    - type: http
      http01:
        ingress:
          ingressClassName: traefik-cert-manager
```

#### Let's Encrypt with DNS01 (Cloudflare)
```yaml
issuer:
  name: letsencrypt-dns01
  enabled: true
  production: true
  issuerEmail: admin@yourdomain.com
  secret: letsencrypt-dns01-private-key
  solvers:
    - type: dns
      cloudProvider: cloudflare
      issuerEmail: admin@yourdomain.com
      cloudProviderSecretRef:
        name: cloudflare-api-token
        key: api-token
      dnsNames:
        - "*.yourdomain.com"
        - "yourdomain.com"
```

#### Step CA
```yaml
issuer:
  name: step-ca
  enabled: true
  stepCA:
    enabled: true
    caBundle: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..."
  solvers:
    - type: http
      http01:
        ingress:
          ingressClassName: traefik-cert-manager
```

## Examples Directory

The `examples/` directory contains ready-to-use configuration files:

- `values-letsencrypt-example.yaml` - Comprehensive Let's Encrypt example (uses ClusterIssuer template)
- `values-http.yaml` - Simple Let's Encrypt HTTP01 challenge
- `values-cloudflare.yaml` - Cloudflare DNS01 challenge
- `values-route53.yaml` - Route53 DNS01 challenge
- `values-multiple-solvers.yaml` - Multiple challenge solvers

For the Step CA helm chart, use `argocd-helm-charts/step-ca/examples/values.yaml`.

## Deployment

### Using ArgoCD

1. Create values file in your kubeaid-config repository:
   ```
   k8s/{clustername}/argocd-apps/values-cert-manager.yaml
   ```

2. Reference the values file in your ArgoCD Application:
   ```yaml
   sources:
     - repoURL: https://github.com/Obmondo/KubeAid
       path: argocd-helm-charts/cert-manager
       targetRevision: HEAD
       helm:
         valueFiles:
           - $values/k8s/{clustername}/argocd-apps/values-cert-manager.yaml
   ```

### Using Helm

```bash
helm install cert-manager ./argocd-helm-charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values examples/values-letsencrypt-production.yaml
```

## Secrets Management

### Cloudflare API Token
```bash
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=your-cloudflare-api-token \
  --namespace=cert-manager
```

### Sealed Secrets (Recommended)
```bash
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=your-cloudflare-api-token \
  --namespace=cert-manager \
  --dry-run=client -o yaml | kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets  \
  -o yaml > cloudflare-api-token-secret.yaml
```

## Troubleshooting

### Common Issues

1. **Certificate not issued**
   ```bash
   kubectl get clusterissuer
   kubectl describe clusterissuer letsencrypt-prod
   ```

2. **ACME challenges failing**
   ```bash
   kubectl logs -n cert-manager deployment/cert-manager
   kubectl get challenges
   ```

3. **DNS01 challenges failing**
   - Verify DNS provider credentials
   - Check DNS propagation
   - Verify domain ownership

### Useful Commands

```bash
# Check ClusterIssuer status
kubectl get clusterissuer

# Check certificate status
kubectl get certificates

# View cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate details
kubectl describe certificate <certificate-name>

# Check challenges
kubectl get challenges
kubectl describe challenge <challenge-name>
```

## Backup and Recovery

### Important Secrets to Backup
- ACME server account credentials
- Cloud provider API tokens
- Step CA certificates and keys

### Backup Commands
```bash
# Backup ACME account secret
kubectl get secret -n cert-manager -o yaml > cert-manager-secrets.yaml

# Backup ClusterIssuer configurations
kubectl get clusterissuer -o yaml > clusterissuers.yaml
```

## Configuration Reference

### Values File Structure

```yaml
# cert-manager core configuration
cert-manager:
  installCRDs: true
  clusterResourceNamespace: cert-manager
  global:
    leaderElection:
      namespace: cert-manager
  prometheus:
    enabled: true
    servicemonitor:
      enabled: true

# ClusterIssuer configuration
issuer:
  name: letsencrypt
  enabled: false
  production: false
  issuerEmail: admin@example.com
  secret: letsencrypt-private-key
  stepCA:
    enabled: false
    caBundle: ""
  selfSigned: false
  solvers:
    - type: http
      http01:
        ingress:
          ingressClassName: traefik-cert-manager

# Security and features
networkpolicies: false
enableCertificateOwnerRef: true
```

## Best Practices

1. **Use staging first**: Test with Let's Encrypt staging before production
2. **Monitor certificates**: Set up alerts for certificate expiration
3. **Backup secrets**: Regularly backup ACME account credentials
4. **Use DNS01 for wildcards**: DNS01 challenges support wildcard certificates
5. **Rate limiting**: Be aware of Let's Encrypt rate limits
6. **Security**: Enable network policies in production

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Step CA Documentation](https://smallstep.com/docs/step-ca/)
- [ACME Challenge Types](https://cert-manager.io/docs/configuration/acme/)
- [DNS01 Providers](https://cert-manager.io/docs/configuration/acme/dns01/)




# cert-manager Runbook

A brief runbook for what to do when some of the alerts from this mixin start firing. This is a bit of a WIP - if you spot anything that needs tweaking contributions are welcome!

- [CertManagerAbsent](#certmanagerabsent)
- [CertManagerCertExpirySoon](#certmanagercertexpirysoon)
- [CertManagerCertNotReady](#certmanagercertnotready)
- [CertManagerHittingRateLimits](#certmanagerhittingratelimits)

## CertManagerAbsent

This alert fires when there is no cert-manager endpoint discovered by Prometheus. Causes could be a few things.

- Ensure cert-manager is up and running.
- Ensure service discovery is configured correctly for cert-manager.

## CertManagerCertExpirySoon

A certificate that cert-manager is maintaining is due to expire within 21 days. Typically ACME certs are updated 30 days before expiry, so this is unusual.

Ensure the certificate issuer is configured correctly. Check cert-manager logs for errors renewing this certificate.

*NOTE: Versions of cert-manager before 0.16.0 do not remove metrics for deleted certificates. Rolling cert-manager or upgrading cert-manager should resolve this.*

## CertManagerCertNotReady

A certificate has not been ready to serve traffic for at least 10m. Typically this means the cert is not yet signed. If the cert is being renewed or there is another valid cert, the ingress controller _should_ be able to serve that instead. If not, need to investigate why the certificate is not yet ready.

Ensure cert-manager is configured correctly, no ACME/LetsEncypt rate limits are being hit. Ensure RBAC permissions are still correct for cert-manager.

## CertManagerHittingRateLimits

Cert-manager is being rate-limited by the ACME provider. Let's Encrypt rate limits can last for up to a week. There could be up to a weeks delay in provisioning or renewing certificates, depending on the action that's being rate limited.

Let's Encrypt suggest the application process for extending rate limits can take a week. Other ACME providers could likely have different rate limits.

[Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

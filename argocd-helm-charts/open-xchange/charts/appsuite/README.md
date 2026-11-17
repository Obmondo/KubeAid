# App Suite Stack Chart

This stack chart is a "full stack deployment" of App Suite. It has Istio support
built in.

# Istio

## App Suite root path

This chart allows to configure the path under which App Suite becomes available.
By default the path is `/appsuite`.

This can get configured with the following snippet in your `values.yaml`:

```
global:
    appsuite:
        appRoot: "/appsuite"
```

`appRoot` must start with a slash, but must not end with a slash.

## Adding additional routes

It is possible to add additional services to the VirtualHost provided by App Suite.
The additional service needs to be located in the same namespace as App Suite itself.

To rewrite an exact path match to another path use the following example:

```
appsuite:
    istio:
        virtualServices:
            appsuite:
                extraRoutes:
                    - name: name-of-extra-route
                      matchExact:
                          - "/api/new-service"
                      rewrite: "/"
                      destinationHost: "new-service"
```

To rewrite a path prefix to another path use the following example:

```
appsuite:
    istio:
        virtualServices:
            appsuite:
                extraRoutes:
                    - name: name-of-extra-route
                      matchPrefix:
                          - "/api/new-service"
                      rewrite: "/"
                      destinationHost: "new-service"
```

To rewrite the path based on a regular expressione use the following example:

```
appsuite:
    istio:
        virtualServices:
            appsuite:
                extraRoutes:
                    - name: name-of-extra-route
                      matchRegex:
                          - "^/new-service/(.*)$"
                      rewriteMatchRegex: "^/new-service/(.*)/api/(.*)$"
                      rewriteRegex: "/\1/\2"
                      destinationHost: "new-service"
```

By default, the Helm release name will be added to the route's `destinationHost`.
This might not be necessary for services that have not been deployed with a release name prefix.
Therefore, the addition of the release name can be disabled with `addReleaseName: false`:

```
appsuite:
    istio:
        virtualServices:
            appsuite:
                extraRoutes:
                    - name: name-of-extra-route
                      matchRegex:
                          - "^/new-service/(.*)$"
                      rewriteMatchRegex: "^/new-service/(.*)/api/(.*)$"
                      rewriteRegex: "/\1/\2"
                      destinationHost: "new-service"
                      addReleaseName: false
```

## Security headers

To enable security headers to configure referrer policy and transport security:
```
appsuite:
    istio:
        securityHeaders:
            enabled: true
```

## Destination rules

The chart renders one Istio `DestinationRule` per core-mw service. Each keeps a
user or client on one core-mw pod through a consistent hash: a cookie for
`appsuite` (http-api), the `Authorization` header for `dav` (sync) and
`businessmobility`. Per block, these keys are passed through to Istio:

| Key | Rendered into |
|-----|---------------|
| `istio.destinationRules.<block>.tls` | `trafficPolicy.tls` |
| `istio.destinationRules.<block>.outlierDetection` | `trafficPolicy.outlierDetection` |
| `istio.destinationRules.<block>.localityLbSetting` | `trafficPolicy.loadBalancer.localityLbSetting` |

**Warning:** setting `outlierDetection` switches on Istio's locality failover
for that host, since it is enabled mesh-wide by default. Each ingress gateway
then hashes only over the core-mw pods in its own zone. If gateways in several
zones serve one user, the user is spread across pods and per-pod state such as
mail compose (uploads, inline images) breaks. Disable locality load balancing
for the rule in that case:

```
appsuite:
    istio:
        destinationRules:
            appsuite:
                outlierDetection:
                    consecutive5xxErrors: 5
                    interval: 5s
                    baseEjectionTime: 30s
                    maxEjectionPercent: 100
                localityLbSetting:
                    enabled: false
```

# Optional dependencies

## Redis

By default, `core-ui-middleware` is configured to start one pod. When you plan to
scale it to a higher value, you will need `Redis`. This allows all `core-ui-middleware`
pods to communicate and synchronize with each other.

The following configuration snippet can be used:

```
appsuite:
  core-ui-middleware:
    redis:
      enabled: true
      host: appsuite-redis-master

redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: false
  master:
    persistence:
      enabled: false
```

For this usecase its recommened not to scale `Redis` itself, as this might slow
down `core-ui-middleware` due to additional overhead.

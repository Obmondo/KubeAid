# Changelog

## v1.16.0

  * Rely on upstream docker-entry script to install composer plugins and skins using new `ROUNDCUBEMAIL_COMPOSER_PLUGINS` env variable (part of !21 by @olegeech-me)
  * Fixes crashloop when using plugins with SQL init scripts such as rcguard (part of !21 by @olegeech-me)
  * Quoting composer cmd to avoid unsafe shell (>) redirects (part of !21 by @olegeech-me)
  * Add setting `ingress.useTLS` to allow deploying plain HTTP ingress (part of !21 by @olegeech-me)
  * Added `additionalEnv`, `additionalVolumeMounts` and `additionalVolumes` fields (!18 by @johnstarx)

## v1.15.0

  * Upgraded roundcube to v1.6.9

## v1.14.0

  * Upgraded roundcube to v1.6.8

## v1.13.0

  * Upgraded roundcube to v1.6.7

## v1.12.0

  * FINALLY! Upgraded roundcube to v1.6.6 (#6)
  * Upgraded `bitnami/common` to v2.19.1
  * Upgraded `nginx` to v1.25.4
  * Fixed non-working `ingress.path` setting (#8)
  * Added setting `deployment.containers.nginx.image` to allow to override nginx image (part of !16 by @ozguryazilimas)
  * Added setting `config.customPhpFpmConfig` to allow to define custom PHP-FPM settings (part of !16 by @ozguryazilimas)
  * Added setting `deployment.imagePullSecrets` to allow to refer to custom ImagePullSecrets (part of !16 by @ozguryazilimas)
  * Added support for `deployment.serviceAccountName` and `rbac`, allowing greater flexibility and compliance with OKD security models (!12 by @Intimaria)
  * Allow for databases to be created directly from this chart, starting with PostgreSQL by Zalando Postgres Operator

## v1.11.1

  * Changed nginx configuration to allow OAuth login (!11 by @alexanderkehr)
  * Upgraded `bitnami/common` to v2.9.0

## v1.11.0

  * Added support for `deployment.initContainers` (!10 by @.wojtek)
  * Upgraded `bitnami/common` to v2.6.0

## v1.10.0

  * Added support for `ingress.tls.secretName` to be able to refer to an existing secret (!8 by @kaktus42)
  * Upgraded `bitnami/common` to v2.4.0

## v1.9.0

  * Added support for `ingress.ingressClassName` (!4 by @stefanandres)
  * Configurable deployment strategy (!5 by @dploeger)
  * Use associative arrays instead of objects for complex plugin options (!6 by @dploeger)
  * Set `COMPOSER_ALLOW_SUPERUSER` to `1` to allow plugin installation via composer (!7 by @teknofile)
  * Upgraded `bitnami/common` to v2.2.5
  * upgraded nginx image to v1.23.3

## v1.8.1

  * Added `client_max_body_size` to nginx sidecar (#5 by @firemdkfighter)
  * Upgraded `bitnami/common` to v2.0.3

## v1.8.0

  * **Upgraded roundcube to v1.6.0, see https://github.com/roundcube/roundcubemail/releases/tag/1.6.0 for breaking changes for custom configuration in Roundcube**
  * **Set default theme to `elastic`**
  * Allow to install custom skins (see `config.skins` parameter in `values.yaml`)
  * **Removed option `config.plugins.managesieve.config.port`, added port portion to `config.plugins.managesieve.config.host`**
  * Changed from apache to nginx with php-fpm
  * Updated `bitnami/common` to v1.16.1

## v1.7.1

  * Upgraded roundcube to v1.5.3

## v1.7.0

  * Added JSON Schema support (see `values.schema.json`) (#3)
  * Improved `values.json` documentation
  * Allow enabling/disabling Ingress resource
  * Removed unused/unsupported `imap.username` and `imap.password` settings

## v1.6.0

  * Improved plugin configuration rendering: Now allows for complex types such as maps and slices
  * Allow to modify resources configuration (!2)
  * Updated `bitnami/common` to v1.13.1

## v1.5.0

  * Added support to automatically install plugins via composer

## v1.4.1

  * Upgraded roundcube to v1.5.2

## v1.4.0

  * Improved `NetworkPolicy` configuration
  * Disabled `NetworkPolicy` by default
  * Fixed: For `NetworkPolicy` resource, check `networkPolicy.enabled`, not `pdb.enabled`

## v1.3.1

  * Do not add roundcube-logo.png to helm chart package (smaller package file size)

## v1.3.0

  * Updated bitnami/common dependency to v1.10.3
  * Updated roundcube default image and chart version to v1.5.1

## v1.2.0

  * Added NetworkPolicy
  * Added support for custom roundcube configuration (e.g. plugins)
  * Renamed `config.php` to `config.customPhpConfig`
  * Improved plugin configuration

## v1.1.0

  * Fixed roundcube version to `1.4.11`
  * Updated `NOTES.txt`
  * Allow for additional labels and annotations per Kubernetes resource
  * Allow setting `ipFamilyPolicy` for service, defaults to `PreferDualStack`
  * Allow for custom PHP configuration
  * Improved nginx session stickyness configuration

## v1.0.1

  * Added Roundcube logo as chart icon

## v1.0.0

  * First release

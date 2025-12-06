## v0.83.3 (2025-11-28)

### New features

- Update GitLab Runner version to v18.6.3

## v0.83.2 (2025-11-25)

### New features

- Update GitLab Runner version to v18.6.2

## v0.83.1 (2025-11-21)

### New features

- Update GitLab Runner version to v18.6.1

## v0.83.0 (2025-11-20)

### New features

- Update GitLab Runner version to v18.6.0
- feat: add native envFrom [!521](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/521) (zadkiel @zadkiel)

## v0.82.0 (2025-10-17)

### New features

- Update GitLab Runner version to v18.5.0

## v0.81.0 (2025-09-18)

### New features

- Update GitLab Runner version to v18.4.0

### Maintenance

- Chore(values): update ExternalSecret to v1 [!523](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/523) (zadkiel @zadkiel)

## v0.79.2 (2025-08-21)

### New features

- Update GitLab Runner version to v18.2.2

## v0.79.1 (2025-07-28)

### New features

- Update GitLab Runner version to v18.2.1

## v0.79.0 (2025-07-12)

### New features

- Update GitLab Runner version to v17.11.4

## v0.76.3 (2025-06-11)

### New features

- Update GitLab Runner version to v17.11.3

## v0.76.2 (2025-05-23)

### New features

- Update GitLab Runner version to v17.11.2

## v0.76.1 (2025-05-05)

### New features

- Update GitLab Runner version to v17.11.1

## v0.76.0 (2025-04-17)

### New features

- Update GitLab Runner version to v17.11.0

## v0.75.0 (2025-03-14)

### New features

- Update GitLab Runner version to v17.10.0

## v0.74.0 (2025-02-20)

### New features

- Update GitLab Runner version to v17.9.0
- Add extra containers [!494](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/494)

### Bug fixes

- Improve authentication token detection [!513](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/513)

### Maintenance

- Update liveness and readiness probe doc [!512](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/512)
- Increase default period for livenessProbe [!511](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/511)
- Run CI jobs in kubernetes [!504](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/504)

## v0.73.0 (2025-01-10)

### New features

- Update GitLab Runner version to v17.8.0
- Add deploymentLabels interpolation [!502](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/502) (Sarafa Lawal @afaras72)

## v0.71.0 (2024-11-15)

### New features

- Update GitLab Runner version to v17.6.0

### Bug fixes

- fix: Change interpreter of session-server scripts to bash [!495](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/495) (Lukas Rath @rusLukasRath)
- Fix session server ingress annotations [!498](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/498) (Miguel Sacristán @tete17)

### Maintenance

- Update CHANGELOG after multiple patches [!500](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/500)
- Remove gitlab chart deps.io update trigger [!497](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/497)
- Update CONTRIBUTING.md and LICENSE [!501](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/501)

## v0.70.3 (2024-11-01)

### New features

- Update GitLab Runner version to v17.5.3

## v0.70.2 (2024-10-23)

### New features

- Update GitLab Runner version to v17.5.2

## v0.69.2 (2024-10-23)

### New features

- Update GitLab Runner version to v17.4.2

## v0.69.1 (2024-10-23)

### New features

- Update GitLab Runner version to v17.4.1

## v0.68.3 (2024-10-23)

### New features

- Update GitLab Runner version to v17.3.3

## v0.68.2 (2024-10-23)

### New features

- Update GitLab Runner version to v17.3.2

## v0.67.3 (2024-10-23)

### New features

- Update GitLab Runner version to v17.2.3

## v0.67.2 (2024-10-23)

### New features

- Update GitLab Runner version to v17.2.2

## v0.66.2 (2024-10-23)

### New features

- Update GitLab Runner version to v17.1.2

## v0.65.3 (2024-10-23)

### New features

- Update GitLab Runner version to v17.0.3

## v0.64.4 (2024-10-23)

### New features

- Update GitLab Runner version to v16.11.4

## v0.63.1 (2024-10-23)

### New features

- Update GitLab Runner version to v16.10.1

## v0.62.2 (2024-10-23)

### New features

- Update GitLab Runner version to v16.9.2

## v0.70.1 (2024-10-18)

### New features

- Update GitLab Runner version to v17.5.1

## v0.70.0 (2024-10-17)

### New features

- Update GitLab Runner version to v17.5.0
- Add podlabels interpolation [!492](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/492) (Ivan Katliarchuk @Ikatliarchuk)

### Other changes

- Add Ingress support for Session Server [!490](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/490) (Ummet Civi @ummetcivi)

## v0.69.0 (2024-09-19)

### New features

- Update GitLab Runner version to v17.4.0

### Bug fixes

- Add env vars if secret is provided [!489](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/489)
- Revert the system_id generation [!488](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/488)
- Use a more generic approach to APISERVER calls [!487](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/487) (Zadjad Rezai @zadjadr)

### Maintenance

- Enable by default the `unregisterRunners` property and document its behavior [!441](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/441)

### Other changes

- runtimeClassName for deployments [!485](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/485) (Piotr Roszatycki @dex4er-user)

## v0.68.1 (2024-08-21)

### New features

- Update GitLab Runner version to v17.3.1

### Bug fixes

- Add env vars if secret is provided [!489](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/489)
- Revert the system_id generation [!488](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/488)

## v0.68.0 (2024-08-09)

### New features

- Update GitLab Runner version to v17.3.0
- Add support for probe-level termination grace period [!484](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/484) (panos @panos--)
- Generate system id when installing GitLab Runner through the Helm Chart [!417](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/417)

### Bug fixes

- Sanitize server session IP Address [!481](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/481)

### Maintenance

- Merge back 0.64, 0.65, 0.66 and 0.67 patches in main branch [!486](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/486)
- Remove env vars if secret is provided [!482](https://gitlab.com/gitlab-org/charts/gitlab-runner/-/merge_requests/482) (Juan José Ruiz Romero @jjotah)

## v0.67.1 (2024-07-26)

### New features

- Update GitLab Runner version to v17.2.1

## v0.66.1 (2024-07-26)

### New features

- Update GitLab Runner version to v17.1.1

## v0.65.2 (2024-07-26)

### New features

- Update GitLab Runner version to v17.0.2

## v0.64.3 (2024-07-26)

### New features

- Update GitLab Runner version to v16.11.3

## v0.67.0 (2024-07-18)

### New features

- Update GitLab Runner version to v17.2.0
- Make livenessProbe and readinessProbe configurable !483
- Add support for different service types for session-server !476 (Ummet Civi @ummetcivi)
- Ignore timeout on verify command for the livenessProbe !457 (Thomas de Grenier de Latour @thomasgl-orange)

### Bug fixes

- Fix the register-the-runner script !479 (Jeremy Huntwork @jhuntwork)

### Maintenance

- Remove registration token integration test !477

## v0.64.2 (2024-07-07)

### New features

- Update GitLab Runner version to v16.11.2

### Maintenance

- Remove registration token integration test !477

## v0.65.1 (2024-07-06)

### New features

- Update GitLab Runner version to v17.0.1

## v0.66.0 (2024-06-20)

### New features

- Update GitLab Runner version to v17.1.0
- Make lifecycle options configurable in the deployment !473 (Marcel Eichler @marcel1802)
- Add dedicated ServiceAccount configuration !415 (Fabian Schneider @fabsrc)

### Bug fixes

- Fix replicas value check for nil to work also with Terraform !478 (Sabyrzhan Tynybayev @sabyrzhan)
- Update list of rules to be added to the rbac role permissions as per documentation !471 (Ismael Posada Trobo @iposadat)

### Maintenance

- Remove registration token integration test !477

## v0.65.0 (2024-05-23)

### New features

- Update GitLab Runner version to v17.0.0

### Maintenance

- Default to https in values.yaml !470

### Other changes

- chore: set the checkInterval value the same as in the main documents. !472 (Michel Santello @michel.santello)

## v0.64.1 (2024-05-03)

### New features

- Update GitLab Runner version to v16.11.1

## v0.64.0 (2024-04-18)

### New features

- Update GitLab Runner version to v16.11.0
- Add support for connection_max_age parameter !468
- Propagate Service Account Name from values !367 (Martin Odstrčilík @martin.odstrcilik)

### Bug fixes

- Fix liveness probe for Runner Pod !466

## v0.63.0 (2024-03-22)

### New features

- Update GitLab Runner version to v16.10.0

### Bug fixes

- Remove the 'replicas' field from the helm template if not used by user !467 (Alexis Boissiere @alexis974)

## v0.62.1 (2024-03-01)

### New features

- Update GitLab Runner version to v16.9.1

## v0.62.0 (2024-02-15)

### New features

- Update GitLab Runner version to v16.9.0
- Template the image string to allow using `{{.Chart.AppVersion}}` reference !464 (Marc Bollhalder @NoRelect)
- Add hostname option !463
- Fix liveness check for runners with multiple tags !462 (Arran Walker @ajwalker)
- Add support for extra objects and env vars !451 (Caleb Hansard @caleb.hansard)

### Bug fixes

- Convert Values.replicas from float64 to int64 !465
- Remove function keyword in register script !461
- Add and use isSessionServerAllowed helper !459 (Florian Berchtold @florian.berchtold)
- Remove function keyword in register script !461
- feat: add tpl in secret helper template !455 (Frederic Mereu @frederic.mereu)
- Fix non terminating runner in register loop !450
- fix: immediately use replica value to allow 0 !460 (d3adb5 @d3adb5)
- Fix non terminating runner in register loop !450

### Maintenance

- Improve wording of comments !439 (Kolja Lucht @k0jak)

## v0.61.2 (2024-02-09)

### New features

- Update GitLab Runner version to v16.8.0

### Bug fixes

- Remove function keyword in register script !461

## v0.61.1 (2024-02-05)

### New features

- Update GitLab Runner version to v16.8.0

### Bug fixes

- Fix non terminating runner in register loop !450

## v0.61.0 (2024-01-19)

### New features

- Update GitLab Runner version to v16.8.0

## v0.60.0 (2023-12-21)

### New features

- Update GitLab Runner version to v16.7.0

### Bug fixes

- Keep tag list for registration token !452
- Keep tag list for registration token !452

### Other changes

- Allow user-defined deployment strategies for multi-replica deployments !427 (Thomas Spear @tspearconquest)

## v0.59.2 (2023-11-25)

### New features

- Update GitLab Runner version to v16.6.1

## v0.59.1 (2023-11-20)

### Bug fixes

- Keep tag list for registration token !452

## v0.59.0 (2023-11-17)

### New features

- Update GitLab Runner version to v16.6.0
- Added topologySpreadConstraints value !432 (Kostya Yag @kartograph9)

### Bug fixes

- Fix support for `runnerToken`, and prevent setting deprecated environment variables when using an external secret controller to inject an authentication token instead of passing the value in via helm !429 (Thomas Spear @tspearconquest)
- Update the default probeTimeoutSeconds to 3 seconds !448
- Allow overriding image.registry to remove slash !447 (Keith Chason @keith.chason)
- Update liveness probe to support authentication token !446

### Maintenance

- Make podSecurityContext values propagate correctly !449 (Viktor Lindström Ahlstedt @viktorla)

## v0.58.2 (2023-11-03)

### Bug fixes

- Update the default probeTimeoutSeconds to 3 seconds !448

## v0.58.1 (2023-10-24)

### Bug fixes

- Update liveness probe to support authentication token !446

## v0.58.0 (2023-10-20)

### New features

- Update GitLab Runner version to v16.5.0
- Add shutdown_timeout flag for global section config !435 (Maxim Tacu @mtacu)

### Bug fixes

- Add missing rbac when debugging services !442 (Ismael Posada Trobo @iposadat)
- Adjust the runner image to match the configured podSecurityContext !434 (Harald Dunkel @hdunkel)
- Support for external secrets added via values.yaml envVars value; avoid setting volumes and volume mounts for nonexistent secrets !426 (Thomas Spear @tspearconquest)
- Make livenessProbe actually probe for a working runner !404 (fiskhest @fiskhest)
- helm: fix runners.config template rendering !386 (Viktor Oreshkin @stek29)

### Maintenance

- Add ephemeral-storage example in resources.requests and resources.limits !443
- Update broken and outdated links in Helm chart values.yaml !438 (Kolja Lucht @k0jak)

## v0.57.1 (2023-10-06)

### New features

- Update GitLab Runner version to v16.3.3

## v0.56.2 (2023-10-06)

### New features

- Update GitLab Runner version to v16.3.2

## v0.56.1 (2023-09-18)

### New features

- Update GitLab Runner version to v16.3.1

## v0.56.0 (2023-08-21)

### New features

- Update GitLab Runner version to v16.2.1

## v0.55.0 (2023-07-23)

### New features

- Update GitLab Runner version to v16.1.1

## v0.54.0 (2023-06-21)

### New features

- Update GitLab Runner version to v16.0.3

## v0.53.2 (2023-06-08)

### New features

- Update GitLab Runner version to v16.0.2

### Bug fixes

- Revert cache settings through Kubernetes secret in values yaml !406
- Take in account registration token from secret !405
- Support empty rules defined in the values.yaml !402

### Maintenance

- Remove reference to rbac.resources and rbac.verbs !403

## v0.52.1 (2023-06-02)

### New features

- Update GitLab Runner version to v15.11.1

## v0.53.1 (2023-05-25)

### New features

- Update GitLab Runner version to v16.0.1

## v0.53.0 (2023-05-22)

### New features

- Update GitLab Runner version to v16.0.0

### Maintenance

- Adapt the Helm Chart to support the next Token Architecture !398
- Remove namespace and cache deprecated fields from the Helm Chart project !397
- Remove all deprecated fields that can be resolved with template merging !393
- Fix failure in integration tests !390

## v0.52.0 (2023-04-22)

### New features

- Update GitLab Runner version to v15.11.0

### Bug fixes

- Enable ability to use tini instead of dumb-init !385
- Invalid yaml when creating service account with no annotations !381 (Zev Isert @zevisert)

### Maintenance

- Fix failure in integration tests !390
- Add merge release config to be executed after stable branches are merged into the main branch !387

## v0.48.0 (2022-12-17)

### New features

- Update GitLab Runner version to 15.7.0

## v0.47.0 (2022-11-22)

### New features

- Update GitLab Runner version to 15.6.0

## v0.46.0 (2022-10-21)

### New features

- Update GitLab Runner version to 15.5.0

## v0.45.0 (2022-09-21)

### New features

- Update GitLab Runner version to 15.4.0
- Add secrets update permission to RBAC example provided !349 (Tim Hobbs @hobti01)

### Bug fixes

- Revert "Merge branch 'feature/unregister-one-runner' into 'main'" !362

### Maintenance

- Fix the pipeline being blocked by development release !357
- Docs: Update values.yaml comments to reference kubernetes service accounts docs !310

## v0.44.0 (2022-08-19)

### New features

- Update GitLab Runner version to 15.3.0
- Add secrets update permission to RBAC example provided !349 (Tim Hobbs @hobti01)

### Maintenance

- Fix the pipeline being blocked by development release !357

### Documentation changes

- Docs: Update values.yaml comments to reference kubernetes service accounts docs !310

## v0.43.0 (2022-07-20)

### New features

- Update GitLab Runner version to 15.2.0

### Documentation changes

- Fix some dead links !356 (Ben Bodenmiller @bbodenmiller)

## v0.42.0 (2022-06-20)

### New features

- Update GitLab Runner version to 15.1.0
- Add priority classname !350
- Update namespaces to be consistent across manifests !343 (blacktide @blacktide)
- Add freely configurable securityContext to deployment !354
- Add possibility to overwrite default image registry !351 (Patrik Votoček @vrtak-cz)
- Make session server service annotations configurable !336 (Matthias Baur @m.baur)

### Maintenance

- Add volume and volumeMount support to runner deployment !348
- ci: Update Helm from 3.4.1 to 3.7.2 !347 (Takuya Noguchi @tnir)
- Update Docker to 20.10 on integration test !346 (Takuya Noguchi @tnir)
- Update default registry to GitLab Runner registry !345
- Update casing of GitLab in values YAML file !344 (Ben Bodenmiller @bbodenmiller)
- Remove unneeded rbac role !335 (Matthias Baur @m.baur)

## v0.41.0 (2022-05-19)

### New features

- Update GitLab Runner version to 15.0.0
- Add the ability to unregister only one runner !329 (LAKostis @LAKostis)
- Remove init container and instead project secrets !312
- Don't repeat chart name if release name starts with the chart name !232 (Ahmadali Shafiee @ahmadalli)

### Maintenance

- Use Helm 3 instead of 2.16.9 on lint/release jobs !342 (Takuya Noguchi @tnir)

## v0.40.0 (2022-04-20)

### New features

- Update GitLab Runner version to 14.10.0
- Add the possibility to configure maximum timeout that will be set for jobs when using the runner !341 (Adrien Gooris @adrien.gooris)

### Maintenance

- Add a post-release CI job to trigger a deps pipeline in Charts repo !339
- Add helm install integration test !326
- Make loadBalancerSourceRanges of Session Server configurable !334 (Matthias Baur @m.baur)

## v0.39.0 (2022-03-21)

### New Features

- Update GitLab Runner version to 14.9.0

### Bug fixes

- Disable metrics endpoint by default !337

### Maintenance

- Update labels according to latest taxonomy !338

## v0.38.1 (2022-03-02)

### New Features

- Update GitLab Runner version to 14.8.2

## v0.38.0 (2022-02-21)

### Maintenance

- Fix urls with runners configuration information !314 (Dmitriy Stoyanov @DmitriyStoyanov)
- k8s rbac: add more resources in comment. !307 (Chen Yufei @cyfdecyf)
- Add dependency scanning to Runner Helm Chart project !331

## v0.37.2 (2022-01-24)

### Bug fixes

- Fix appVersion to 14.7.0

## v0.37.1 (2022-01-20)

### Bug fixes

- Set sessionServer to false by default !332

## v0.37.0 (2022-01-19)

### New Features

- Update GitLab Runner version to 14.7.0
- Add support for interactive web terminal !320

## v0.36.0 (2021-12-18)

### New features

- Update GitLab Runner version to 14.6.0

### Bug fixes

- Fix prometheus annotation unquoted value !323

### GitLab Runner distribution

- Fix the security release rule in .gitlab-ci.yml !324
- Fail the stable release job on curl failures !322

## v0.35.3 (2021-12-13)

### Maintenance

- Fix prometheus annotation unquoted value !323

## v0.35.2 (2021-12-10)

### Security

- Update GitLab Runner version to 14.5.2

## v0.35.1 (2021-12-01)

### Security

- Update GitLab Runner version to 14.5.1

## v0.35.0 (2021-11-21)

### New features

- Update GitLab Runner version to 14.5.0

### Maintenance

- Don't run pipelines only for MRs !318
- Update changelog generator configuration !317
- Adds configurable value probeTimeoutSeconds !306 (Kyle Wetzler @kwetzler1)

## v0.34.0-rc1 (2021-10-11)

### New features

- Update GitLab Runner version to 14.4.0-rc1

### Maintenance

- Disallow setting both replicas and runnerToken !289

## v0.33.0 (2021-09-29)

### New features

- Update GitLab Runner version to 14.3.0

### Maintenance

- Update container entrypoint to use `dumb-init` to avoid zombie processes !311 (Georg Lauterbach @georglauterbach)

## v0.32.0 (2021-08-22)

### New features

- Update GitLab Runner version to 14.2.0
- Add support for revisionHistoryLimit !299 (Romain Grenet @romain.grenet1)

## v0.31.0 (2021-07-20)

### New features

- Update GitLab Runner version to 14.1.0

### Bug fixes

- Only add environment variables if values set !295 (Matthew Warman @mcwarman)

## v0.30.0 (2021-06-19)

### New features

- Update GitLab Runner version to 14.0.0

### Bug fixes

- Resolve runner ignores request_concurrency !296

### Maintenance

- refactor: change default brach references to main !298
- Add support for specifying schedulerName on deployment podspec. !284 (Dominic Bevacqua @dbevacqua)

## v0.29.0 (2021-05-20)

### New features

- Update GitLab Runner version to 13.12.0

## v0.28.0 (2021-04-20)

### New features

- Update GitLab Runner version to 13.11.0

### Maintenance

- Pass runners.config through the template engine !290 (Dmitriy @Nevoff89)
- Add role support of individual verbs list for different resources !280 (Horatiu Eugen Vlad @hvlad)
- Use runner namespace for role and role binding if it is specified !256 (Alex Sears @searsaw)
- Add optional configuration values for pod security context `runAsUser` and `supplementalGroups` !242 (Horatiu Eugen Vlad @hvlad)

### Documentation changes

- docs: add notice that we run tpl on runner config !291
- Add comment on imagePullPolicy !288

## v0.27.0 (2021-03-21)

### New features

- Update GitLab Runner version to 13.10.0
- Allow setting deployment replicas !286
- Add support for specify ConfigMaps for gitlab-runner deployment !285
- Allow to mount arbitrary Kubernetes secrets !283

## v0.26.0 (2021-02-22)

### New features

- Update GitLab Runner version to 13.9.0
- Make executor configurable !273 (Matthias Baur @m.baur)

### Other changes

- Typo fix !282 (Ben Bodenmiller @bbodenmiller)

## v0.25.0 (2021-01-20)

### New features

- Support secrets for Azure cache !277
- Update GitLab Runner version to 13.8.0

### Maintenance

- Fix release CI stage failing due to Helm stable deprecation !278
- Update GitLab Changelog configuration !275

### Documentation changes

- Update link to doc in README.md !276

## v0.24.0 (2020-12-21)

### New features

- Update GitLab Runner version to 13.7.0
- add optional 'imagePullSecrets' to deployment !269 (Christian Schoofs @schoofsc)

### Other changes

- Make description configruable !229 (Matthias Baur @m.baur)

## v0.23.0 (2020-11-21)

### New features

- Update GitLab Runner version to 13.6.0
- Allow user to specify any runner configuraton !271

## v0.22.0 (2020-10-20)

### New features

- Update GitLab Runner version to 13.5.0
- Add pull secrets to service account for runner image !241 (Horatiu Eugen Vlad @hvlad)

### Maintenance

- Set allowPrivilegeEscalation to false for gitlab-runner pod !243 (Horatiu Eugen Vlad @hvlad)

### Documentation changes

- Add comment on ubuntu image & securityContext !260

## v0.21.0 (2020-09-21)

### Maintenance

- Update GitLab Runner version to 13.4.0
- Fix changelog generator config to catch all maintenance related labels !255

### Other changes

- Add scripts/security-harness script !258

## v0.20.0 (2020-08-20)

### New features

- Update GitLab Runner version to 13.3.0
- Enable custom commands !250

### Maintenance

- Add `release stable` job for security fork !252
- Update changelog generator to accept new labels !249

## v0.19.0 (2020-07-20)

### New features

- Allow user to define PodSecurityPolicy !184 (Paweł Kalemba @pkalemba)
- Update GitLab Runner version to 13.2.0

### Documentation changes

- Fix external links within values.yaml !248 (Alexandre Jardin @alexandre.jardin)

## v0.18.0 (2020-06-19)

### Maintenance

- Update GitLab Runner version to 13.1.0

### Other changes

- Fix unregister when using token secret !231 (Bernd @arabus)
- Support specifying pod security context. !219 (Chen Yufei @cyfdecyf)

## v0.17.1 (2020-06-01)

### Maintenance

- Update GitLab Runner version to 13.0.1

## v0.17.0 (2020-05-20)

### New features

- Expose settings for kubernetes resource limits and requests overwrites !220 (Alexander Petermann @lexxxel)
- Add support for setting Node Tolerations !188 (Zeyu Ye @Shuliyey)

### Maintenance

- Update GitLab Runner version to 13.0.0
- Update package name in note !234
- Pin CI jobs to gitlab-org runners !222

## v0.16.0 (2020-04-22)

### New features

- Add Service Account annotation support !211 (David Rosson @davidrosson)

### Bug fixes

- Support correct spelling of GCS secret !214 (Arthur Wiebe @arthur65)

### Maintenance

- Remove dependency of `gitlab-runner-builder` runner !221
- Fix linting for forks with a different name than "gitlab-runner" !218
- Install gitlab-changelog installation !217

### Other changes

- Update GitLab Runner version to 12.10.1
- Change listen address to not force IPv6 !213 (Fábio Matavelli @fabiomatavelli)

## v0.15.0 (2020-03-20)

### Maintenance

- Update GitLab Runner version to 12.9.0
- Update changelog generator configuration !212
- Replace changelog entries generation script !209

### Other changes

- Fix values.yaml typo !210 (Brian Choy @bycEEE)

## v0.14.0 (2020-02-22)

- Update GitLab Runner version to 12.8.0

## v0.13.0 (2020-01-20)

- Add podLabels to the deployment !198
- Mount custom-certs in configure init container !202

## v0.12.0 (2019-12-22)

- Add `apiVersion: v1` to chart.yaml !195
- Add documentation to protected Runners !193
- Make securityContext configurable !199
- Update GitLab Runner version to 12.6.0

## v0.11.0 (2019-11-20)

- Variables for RUNNER_OUTPUT_LIMIT, and KUBERNETES_POLL_TIMEOUT !50
- Add support for register protected Runners !185

## v0.10.1 (2019-10-28)

- Update GitLab Runner to 12.4.1

## v0.10.0 (2019-10-21)

- Updated GitLab Runner to 12.4.0
- Use updated project path to release helm chart !172
- Update resources API to stable verson !167
- Add support for specifying log format !170
- Use the cache.secret template to check if the secretName is set !166
- Drop need for helm force update for now !181
- Fix image version detection for old helm versions !173

## v0.9.0 (2019-09-20)

- Use updated project path to release helm chart !172
- Enabling horizontal pod auto-scaling based on custom metrics !127
- Change base image used for CI jobs !156
- Remove DJ as a listed chart maintainer !160
- Release beta version on master using Bleeding Edge image !155
- Update definition of 'release beta' CI jobs !164
- Fix certs path in the comment in values file !148
- Implement support for run-untagged option !140
- Use new location for helm charts repo !162
- Follow-up to adding run-untagged support !165

## v0.8.0 (2019-08-22)

- Add suport for graceful stop !150

## v0.7.0 (2019-07-22)

- Fix broken anchor link for gcs cache docs !135
- Allow user to set rbac roles !112
- Bump used Runner version to 12.1.0 !149

## v0.6.0 (2019-06-24)

- Allow to manually build the package for development branches !120
- When configuring cache: if no S3 secret assume IAM role !111
- Allow to define request_concurrency value !121
- Bump used Runner version to 12.0.0 !138

## v0.5.0 (2019-05-22)

- Bump used Runner version to 11.11.0 !126

## v0.4.1 (2019-04-24)

- Bump used Runner version to 11.10.1 !113

## v0.4.0 (2019-04-22)

- Bump used Runner version to 11.10.0-rc2 !108
- Fix a typo in values.yaml !101
- Add pod labels for jobs !98
- add hostAliases for pod assignment !89
- Configurable deployment annotations !44
- Add pod annotations for jobs !97
- Bump used Runner version to 11.10.0-rc1 !107

## v0.3.0 (2019-03-22)

- Change mount of secret with S3 distributed cache credentials !64
- Add environment variables to runner !48
- Replace S3_CACHE_INSECURE with CACHE_S3_INSECURE !90
- Update values.yaml to remove invalid anchor in comments !85
- Bump used Runner version to 11.9.0 !102

## v0.2.0 (2019-02-22)

- Fix the error caused by unset 'locked' value !79
- Create LICENSE file !76
- Add CONTRIBUTING.md file !81
- Add plain MIT text into LICENSE and add NOTICE !80
- Fix incorrect custom secret documentation !71
- Add affinity, nodeSelector and tolerations for pod assignment !56
- Ignore scripts directory when buildin helm chart !83
- Bump used Runner version to 11.8.0-rc1 !87
- Fix year in Changelog - it's already 2019 !84

## v0.1.45 (2019-01-22)

- Trigger release only for tagged versions !72
- Fixes typos in values.yaml comments !60
- Update chart to bring closer to helm standard template !43
- Add nodeSelector config parameter for CI job pods !19
- Prepare CHANGELOG management !75
- Track app version in Chart.yaml !74
- Fix the error caused by unset 'locked' value !79
- Bump used Runner version to 11.7.0 !82

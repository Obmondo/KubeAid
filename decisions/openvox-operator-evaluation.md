# Why we are not adopting the OpenVox Operator yet

*Evaluated July 2026 against `slauger/openvox-operator` 0.9.6. Recommendation: wait.*

We run OpenVox (Puppet) on Kubernetes with a Helm chart we maintain ourselves,
`argocd-helm-charts/openvox`. It works, but a lot of the plumbing is ours:
certificate backup and CRL cronjobs, custom container entrypoints, a fork of the
upstream puppetserver chart with patches that are still open pull requests. Every
one of those is something we carry.

The [OpenVox Operator](https://github.com/slauger/openvox-operator) promises to
take that burden away. It manages the Puppet server, the certificate authority
and PuppetDB through Kubernetes CRDs, and handles certificate lifecycle
automatically. That is genuinely attractive, so we built a pilot chart
(`argocd-helm-charts/openvox-operator`) and deployed the full stack on a test
cluster to find out whether it could replace what we have.

It cannot, yet. This document explains why, so the question does not have to be
re-investigated from scratch in six months.

## What actually worked

Worth saying first, because the conclusion is negative and the project does not
deserve a dismissive summary.

The stack came up and ran. The certificate authority initialised and reached
`Ready` with a five-year certificate, with renewal and CRL refresh handled by the
controller — exactly the thing we currently do with hand-written cronjobs. The
Puppet server started and served status, PuppetDB started and accepted reports,
Puppet code delivery over a shared volume worked. We then tore the whole thing
down and reinstalled it from scratch to confirm nothing depended on manual
intervention, and it converged unattended.

The design is sound. The problem is the integration surface around it.

## Blocker 1: node registration does not work

This is the one that matters most, and it is not an infrastructure detail — it is
how our business process works.

When a new machine enrols with our Puppet server today, an autosign policy script
runs. That script calls the Obmondo API, which decides whether the machine is
allowed to enrol **and registers it in our inventory**. Signing the certificate
and registering the node are the same action.

The operator does not support policy scripts. It hardcodes its own signing binary
and drives it from declarative rules — certname patterns, CSR attributes — which
can express "does this name match a glob" but cannot call an external system.

There is an apparent workaround in the chart, and we tested it rather than
assuming. It does not work: the operator's value wins, and the CSR is refused.
Even if it had worked, the script needs a client certificate to authenticate to
our API, and the operator provides no way to mount a secret or set an environment
variable on the server pod. Two independent walls.

Closing this needs a new feature upstream. We have drafted the request. Until it
lands, adopting the operator means redesigning how machines enrol and how they
get registered — including a change to the security model, since the gate would
move from "our API approved this machine" to "this machine holds a shared key".

## Blocker 2: it cannot run on our storage

The operator creates its pods running as an unprivileged user but does not tell
Kubernetes to grant that user ownership of the storage volume. On a freshly
created volume, the certificate authority therefore cannot write its own files
and fails to start.

We verified this is not specific to one storage system: it fails on CephFS and on
Ceph block storage, and works only on node-local storage, which is not usable in
production because it does not survive the machine going away. No CRD exposes a
setting to correct it, so it cannot be configured around — only patched by
mutating pods as they are created, which is precisely the kind of glue an
operator is supposed to eliminate.

## Blocker 3: we cannot pin versions

The operator and server container images are published only as `latest` and as
git commit hashes. There is no version tag matching the chart release, and the
chart provides no way to pin by image digest.

We deploy to customers through GitOps, where the version running in a cluster is
determined by what is committed to Git. Shipping `latest` means the running
version can change without any commit recording it, and a rollback is not
reproducible. That is not acceptable for customer infrastructure, independent of
how good the software is.

## Other gaps, none fatal on their own

- **No place for Hiera data.** The operator mounts only the Puppet environments
  directory. Our per-customer Hiera repositories and eyaml encryption keys have
  nowhere to live on the server. This affects every customer we host.
- **External node classification is HTTP-only.** Our classifier is a script; the
  operator only calls a web service. It would have to be rewritten as one.
- **No custom entrypoints.** We lose the mechanism that produces the metrics our
  Puppet agent exporter reads.
- **No Puppetboard.** Not provided; we would run it separately or drop it.
- **Uninstalling deadlocks.** Deleting the application hangs permanently and
  requires manual recovery, and it leaves the CRDs stuck for the whole cluster.
  This matters for disaster recovery, not just tidiness.

## What we contributed back

The evaluation was not wasted effort even though the answer is no.

We filed four issues upstream and one pull request fixing a chart bug that
rejects a perfectly valid configuration, with a regression test. A fifth issue is
drafted for the node registration blocker. We also improved our own
`kubeaid-addons` chart to support PostgreSQL extensions, which OpenVoxDB requires
and which is useful for any future application with the same need.

The pilot chart itself is complete and documented. If the blockers close, we are
not starting over — we redeploy and continue from the functional testing we
deferred.

## Recommendation

**Wait. Do not migrate.** Re-evaluate when the three blockers close.

One caveat worth being explicit about with anyone making plans on this: blocker 1
is a feature request, not a bug report. It depends on a single maintainer
accepting a design change to their project. If they decline, our realistic
options are a significant redesign of how nodes enrol, or staying on our current
chart indefinitely. So "wait" may eventually become "stay".

Nothing about this is urgent. The current setup works and is not affected by any
of the above — the pilot ran in an isolated namespace with its own certificate
authority and no machines attached to it. The cost of this evaluation was a test
deployment, not a migration.

## Where the detail lives

`argocd-helm-charts/openvox-operator/README.md` has the full technical record:
sixteen documented gaps, a value-by-value mapping from our existing chart, the
cluster test log, and the functional tests we deliberately deferred.

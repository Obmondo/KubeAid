# Why GitOps with ArgoCD, not Pulumi, Terraform, or Ansible

When you run Kubernetes in production, the biggest long-term problem is not installing software. It is knowing
what is actually running, who changed it, and why. Engineers make quick fixes directly on the cluster and forget
to write them down. A month later, the cluster no longer matches what anyone thinks it is. This is called drift,
and it is the most common source of production incidents in clusters that do not enforce GitOps.

KubeAid solves this with one rule: **every change goes through Git**. No direct `kubectl` in production. Every
application, every configuration value, every network policy lives in a Git repository. ArgoCD watches those
repositories and continuously keeps the cluster in sync.

## The incident that changed how we think about clusters

A few years ago, one of our on-call engineers got paged at 2 AM. A customer's application was returning 502s.
He SSHed into the cluster, found a misconfigured ConfigMap, and patched it directly with `kubectl edit`. The
application recovered. He went back to sleep.

Three weeks later, a routine Helm upgrade overwrote that ConfigMap with the chart default. The application broke
again — same error, same 2 AM page. This time no one remembered the original fix. It took four hours to diagnose
because there was no record of the first change anywhere.

That is the problem GitOps solves. Not the first incident. The second one — the real-world question of "what did
my colleague change since this last worked?", with no way to answer it because the change never touched Git.

## How KubeAid does this

KubeAid uses two repositories per customer:

| Repository | What lives here |
| ---------- | --------------- |
| [`KubeAid`](https://github.com/Obmondo/KubeAid) | The platform: 118 pre-configured applications with production-tested defaults. Prometheus monitoring, Cilium networking, Traefik ingress, cert-manager, Velero backups. You fork it — so you control when to pull updates from upstream. Obmondo tags releases so you can pin to a version and upgrade on your schedule. |
| `kubeaid-config-<your-org>` | Your cluster config: only what is different from the defaults. Your domain names, your node sizes, your cloud credentials. You own this repo. |

When you want to change something, you open a pull request in your config repo. ArgoCD picks it up automatically
and applies it to the cluster. No SSH access needed. No manual steps. No wondering whether someone else already
applied it.

Here is a real cert-manager Application CR from a production cluster:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  labels:
    kubeaid.io/managed-by: kubeaid   # marks this app as KubeAid-managed
    kubeaid.io/version: 20.1.1       # pinned KubeAid release
    kubeaid.io/sync-order: "10"      # controls apply order across apps
spec:
  destination:
    namespace: cert-manager
    server: https://kubernetes.default.svc
  project: kubeaid
  sources:
    - repoURL: https://github.com/Obmondo/KubeAid
      path: argocd-helm-charts/cert-manager
      targetRevision: 20.1.1         # chart version locked to kubeaid release
      helm:
        valueFiles:
          - $values/k8s/<cluster>/argocd-apps/values-cert-manager.yaml
    - repoURL: https://github.com/<your-org>/kubeaid-config-<your-org>
      targetRevision: HEAD
      ref: values                    # your config repo — only your overrides live here
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true      # only applies resources that are actually out of sync
```

Two sources in one Application is the KubeAid pattern: the chart comes from KubeAid at a pinned version, the
values come from your config repo. ArgoCD merges them at sync time — no templating step, no CI pipeline needed.
When Obmondo cuts a new KubeAid release, you bump `kubeaid.io/version` and get upstream fixes automatically.

For apps that need strict drift enforcement, the `syncPolicy` also includes:

```yaml
syncPolicy:
  automated:
    prune: true    # removes resources deleted from Git
    selfHeal: true # reverts any manual changes made directly on the cluster
```

`selfHeal: true` is the answer to the 2 AM incident above. If the engineer had made that ConfigMap fix through a
pull request, the change would have survived the Helm upgrade — because it would have been in Git, and ArgoCD
would have applied it on top of the chart default. Instead it was a manual change, invisible to everyone, until
it broke a second time.

ArgoCD checks every 3 minutes by default. Any drift from Git is flagged as `OutOfSync` in the dashboard within
minutes, not discovered weeks later during a post-mortem.

## Seeing manual changes before they cause problems

This is the capability that made the biggest difference for us in practice.

When someone makes a manual change directly on the cluster — a `kubectl edit`, a `helm upgrade` run by hand, a
resource patched to unblock a deployment — ArgoCD shows it. The application turns `OutOfSync`. The dashboard
shows exactly which fields changed, what the Git value is, and what the live cluster value is, side by side.

You do not need the person who made the change to remember to tell anyone. You do not need to grep through audit
logs. You open ArgoCD and it is right there.

With `selfHeal: true` enabled, ArgoCD reverts the change automatically on the next reconciliation cycle. For
clusters where you want visibility without automatic revert — for example, during an incident where someone is
making emergency changes — you can leave `selfHeal` off and still see every manual change in the dashboard the
moment it happens.

**One important limitation:** ArgoCD can only see changes to resources it already manages. If someone creates
an entirely new resource on the cluster without going through Git — a manually applied Deployment, a Secret
created with `kubectl create` — ArgoCD does not know about it. It has no baseline to compare against.

This is a known gap. We are currently working on tooling to detect resources on the cluster that are not
managed by GitOps at all — resources that exist outside of any ArgoCD Application. Until that is available,
the discipline of "everything goes through Git" has to be enforced by process, not just by tooling.

Neither Terraform nor Ansible can do this continuously or reliably.

**Terraform** has `terraform plan`, which shows a diff — but only when the statefile accurately reflects reality.
When someone makes a manual change outside of Terraform, the statefile is now wrong. You cannot auto-sync it —
fixing it is a manual task, and you have to already know the drift happened before you can even start. Terraform
will not tell you. You find out when something breaks.

**Ansible** has no statefile at all. It has no memory of what it previously applied and no concept of current
cluster state. Detecting a change would require every individual Ansible module to implement change-detection
support separately — and most do not. Even in the rare cases where a module does support it, the diff quality
is poor and unreliable. Manual changes in production are effectively invisible.

**Puppet and [OpenVox](https://openvox.io/)** (the open-source Puppet fork) are the exception: like ArgoCD,
both run continuously and enforce desired state by design. Change detection and exact diff support is built in
at the platform level — not left to individual modules. They notice and react immediately when someone changes
a managed resource outside of the expected workflow.

The key requirement is: **you need to know immediately when someone changes something in production outside of
GitOps.** Terraform cannot deliver that. Ansible cannot deliver that. ArgoCD can — within 3 minutes,
automatically, without anyone having to remember to run anything.

## Why we chose Cluster API and ArgoCD, not Terraform or Ansible

**Terraform and Ansible are good at creating a cluster — not at keeping it healthy afterwards.**
We used Terraform and Ansible before. They worked well for standing up the initial infrastructure: the VPC,
the node groups, the first application install. The problem is everything that comes after that first apply —
the months and years of keeping the cluster running, upgrading it, recovering from failures. None of those tools
are built to run continuously and tell you when the live cluster stops matching what they think they provisioned.

We now use Cluster API to provision and manage cluster infrastructure, and ArgoCD to manage everything running
inside the cluster. Both are GitOps-native: the desired state lives in Git, the tool reconciles the live system
towards it continuously. That is the key difference.

**Terraform and Ansible are pull-on-demand, not push-on-change.**
You have to remember to run them. ArgoCD runs continuously. The moment something drifts, you see it.

**Git gives you a permanent audit trail.**
Every change has a commit hash, an author, a reviewer, and a timestamp. When something breaks at 2 AM,
`git log` shows exactly what changed, who approved it, and when. With Ansible, the record is whatever your
CI system logged — if it ran at all.

**Upstream projects ship Helm charts, not Pulumi providers.**
Cilium, cert-manager, Traefik, CloudNativePG: all publish and maintain their own Helm charts. Bug fixes land
there first. KubeAid wraps those charts and bumps versions daily — you get upstream fixes without any extra work.

Pulumi and Terraform have Kubernetes providers, but those are maintained separately from the upstream projects.
Using them means owning that translation layer. With Helm, you don't.

## What about Pulumi and KCL?

Pulumi lets you write infrastructure in Go or TypeScript. The appeal is obvious: real programming constructs,
type safety, loops. The problem is that when something breaks, you are debugging a Go or TypeScript program
rather than a Kubernetes resource. Abstraction leaks are inevitable with any tool complex enough to be
Turing-complete.

[KCL](https://www.kcl-lang.io/) avoids most of those problems by staying declarative — a sensible choice for
internal abstractions. But KubeAid already uses Helm charts that upstream projects maintain themselves. Adding
KCL on top means maintaining a translation layer over something that is already maintained for you. That is extra
work with no payoff — for your *own* applications on Kubernetes, though, KCL (or
[KRO](https://kro.run/docs/overview/)) is worth considering.

## Compliance, not just convenience

GitOps is not only an operational nicety — it is how you demonstrate control over change to auditors. Every
production change being a reviewed, timestamped, attributed Git commit is directly what Change Management
processes ask for, and it maps cleanly onto the change-control and traceability requirements in **GDPR**,
**NIS2**, and **ISO 27001:2022**. When an auditor asks "prove that only approved changes reach production, and
show who approved them," `git log` on the config repo *is* the proof — not a screenshot of a ticket that may or
may not reflect what actually happened on the cluster.

## The trade-off, honestly

GitOps means every change goes through a pull request. For teams used to running `kubectl apply` directly, this
feels slower at first. It is. A ConfigMap fix that used to take 30 seconds now takes as long as your PR review
process.

The payoff: every change is documented, reviewed, and reversible. Teams that skip this accumulate undocumented
cluster state that becomes increasingly difficult to reason about. We know — we were one of those teams.

`selfHeal: true` enforces the discipline automatically. There is no mechanism to make a persistent change outside
of Git. That is a feature, not a limitation.

*Companion blog post, with the full 2 AM incident write-up:
[Why We Chose GitOps with ArgoCD](https://obmondo.com/blog/why-gitops-argocd-decisions-01).*

## Sources

- [OpenGitOps Principles](https://opengitops.dev/)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery/tree/main/gitops-wg)
- [GitOps explained, GitLab](https://about.gitlab.com/topics/gitops/)
- [KubeAid argocd-helm-charts](https://github.com/Obmondo/KubeAid/tree/master/argocd-helm-charts)
- [ArgoCD self-heal documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing)

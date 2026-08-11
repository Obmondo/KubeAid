# Decisions made

In this document we've documented the decisions we have made and why.
These are based on decades of experience with large scale operations by our senior staff - and hopefully helps others
to understand the experience from real world issues - that these decisions are based on.

## Everybody hates Yaml

Everybody hates Yaml because:

- It is verbose
- It is lacking typesafety
  You easily type in the wrong value or something - and it just goes ahead and ignores your mistake
- It relies on indentation
  If you wrongly indent - it'll just ignore that entire section - not even tell you

BUT its what Kubernetes choose - so its the end result you need to deliver to Kubernetes.

## Helm sucks

Helm is golang style templating on Yaml.
So yes - just as Yaml sucks - Helm kinda sucks too :)

It does not fix Yamls problems with lack of type safety or indentation.

For this reason some prefer to choose tools that allows for more modern protections against silly mistakes,
such as Pulimi or KCL.

Pulimi allows you to write your Infrastructure as Code in Golang. Nice. But when you use a complete programming
language for doing so - you easily end up having to deal with all the issues of Programming.. That you really
wasn't supposed to bother with for Infrastructure definitions.

Therefore someone invented KCL - https://www.kcl-lang.io/
KCL was built for this purpose and its a very good solution for replacing Helm charts for your own applications.

In reality many actually wanted to simplify the choices for the users of their apps. Helm allows this with values -
but still has all the drawbacks. KCL removes the drawbacks, but its still a programming language - giving "way too
many options" for simplifying.

For this reason many tend to write a Custom Resource Definition - defining types in Kubernetes - that can then be
used with very short Yaml - with type safety and simplicity. It allows your users to define the things you want to
allow them - with ACLs and everything you need to limit their choices supported by Kubernetes.

To make this easier, someone invented KRO - https://kro.run/docs/overview/

So for your own applications on Kubernetes - we recommend using KCL or KRO.

## Open Source community wins - every time

If Yaml and Helm is so lacking, why is KubeAid supported open source applications mainly managed by Helm charts?

Because the reality of open source - is that the ways, the majority chooses to solve their challenges, becomes the
best way to for everyone to benefit and enjoy the hard work of the open source community. If you go your own route -
you have to handle all the challenges yourself - gaining nothing from the collective experience of the entire
community that uses and develops the application you want to benefit from using.

With Kubernetes - everything changes - constantly. There are changes with every major k8s release - and those
happens every 3 months. After 3 major releases, you no longer have security updates - so you better keep
upgrading :)
This means you have to change your Yaml - and ensure its still realiable and safe - every 3 months.
Doing that for every application you use - that others wrote and shared as Open source to save you time -
would be a major load of constant work.

So the fact is - if you want the fewest problems - you follow the community - and communicate and work with them
to resolve issues you identify in the route they're taking. This benefits everyone, and saves you a lot of time
in the long run.

This is why KubeAid has mainly Helm Charts to manage the open source applications - because those are the
officially supported ways for each community - to run and manage their application.

## Security and reliability cannot be an afterthought - and yet its never the first thing

Many handle security, as if its something you just enable - now or later.

We know that its not. Security requires attention to detail and a layered, well designed approach,
as the attackers will otherwise only need to find one mistake in the 1000's of components in our systems,
to gain access and can often stay in your systems, waiting for just the right time to strike.

In KubeAid we try to constantly improve our layered design of everything and keeping attention to small,
but important details - following "principle of least privilege" in the right places.

One example is that we switched to to RustFS for S3 backup storage - because the S3 standard does not
allow for a "add only, no read" access - which is needed to minimize the risk of the backup user.
In most setups backups are pushed to S3 and any attacker who successfully compromised just 1 service - would
have access to overwriting all your backups (often the same backup user is shared amongst many services) and
also to accessing sensitive data by reading previous backups as well.

The same can be said about reliability. We implemented airgapped support - which too few use - but everybody should,
to actually be prepared and ready to handle common problems, with sources going missing from the internet
or being down shortly - ensuring that your services are not affected by this. Its also the best way to improve your
Supply chain security - as it helps you ensure you have the complete overview over your supply chain
dependencies and vulnerabilities.

## Soo many choices

When using Open Source, you have soo many choices for everything.

- Ingress can be done in 10+ ways..
  NGINX, Traefik, Haproxy and so on.

Choices are great - but when you combine these choices into a platform - you end up with your own personal
combination - and all the problems that can come when those choices don't play well with the other choices -
because your personal combination turned out to not be so well used in the community - can give you real grief.

We have been there - done that.

All of our choices - started with trying to compare the options and trying to find arguments that made the choice
easier. But not every choice was easy. Many choices are equally good - and simply comes down to personal taste.
For those cases - the evaluated community size and activity and made the best choie we could. Sometimes we decided
to support multiple options (like Graylog, Loki, OpenObserve and Opensearch/ELK stack for log monitoring) - and
in other cases, we learned from our mistakes and had to change our choice (like switching from Zalando pgsql
operator to Cloudnative-PG).

The biggest benefit with KubeAid - is that you get a platform that supports everything you need - with curated
choices, and configurations for how to achieve the same legislation and compliance needs, that everyone using
IT has.

We are working on documenting each of the decisions we've made and why:

- [GitOps](decisions/gitops.md) - Why Gitops with Argocd and not Pulimi, Terraform or Ansible?
- [Security Scanning](decisions/security-scanning.md) - Why one tool per security layer - Trivy over Kubescape,
  Tetragon over KubeArmor, Kyverno plus in-tree ValidatingAdmissionPolicy - and what each produces as compliance
  evidence.
- *[RemoteAccess](decisions/remoteaccess.md) - How to access services you do not want open to the internet -
  VPN, SSH etc.* (Upcoming)
- *[Ingress](decisions/ingress.md) - How to ingest traffic - with safety and reliability.* (Upcoming)
- *[Operators](decisions/operators.md) - How to operate advanced stuff - such as Databases.* (Upcoming)
- *[Databases](decisions/databases.md) - Postgres, MongoDB, OpenSearch, Elasticsearch, Redis etc.* (Upcoming)
- *[Policy](decisions/policy.md) - Kyverno and OPA/Gatekeeper* (Upcoming)

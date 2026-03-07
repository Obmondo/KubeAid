# CI build and automatic pull requests

**TODO:** Add documentation describing what is actually going on here

To automatically build kubeaid in CI and create a pull request against your own config repository additional configuration
may be required.

### Secrets Required

The `kube-prometheus` needs two secrets thats needs to be present

1. alertmanager-main - It is the secret that contains the alertmanager config file.
   An example template for the alertmanager config can be found [here](https://github.com/Obmondo/KubeAid/blob/main/build/kube-prometheus/examples/alertmanager-config/alertmanager-main.yaml)
2. obmondo-clientcert - This secret contains the `tls.crt` which is the certificate and `tls.key` which is the private key.
   This cert and key must be generated from the puppetserver. And then copied over to the secret
   **Comment:** Which puppetserver is that, and how is that used?

### GitHub

**TODO:** Start by documenting what these pull requests are actually all about....

kubeaid implements a GitHub Action that is used to automatically create pull requests. For this to work the following
variables should be set:

- `API_TOKEN_GITHUB`: GitHub PAT with permission `repo` (Full control of private repositories).
- `OBMONDO_DEPLOY_REPO_TARGET`: Target repository short name, e.g. `awesomecorp/kubeaid-config-awesomecorp`
- `OBMONDO_DEPLOY_REPO_TARGET_BRANCH`: Branch name of kubeaid-config against which you want to build, often `main` or `master`
- `OBMONDO_DEPLOY_PULL_REQUEST_REVIEWERS` (optional): A comma-separated list of usernames of the users that are added as
  reviewers for PRs

As GitHub does not have a concept of repository access tokens like GitLab it's considered best practice to instead
create a user account specifically for this purpose. The user account should only have access to this repository and the
repository referenced in `OBMONDO_DEPLOY_REPO_TARGET`.

In order to be able to create PRs the setting *"Automatically delete head branches"* must be enabled in the target
repository. This can be done by in repository settings under the heading "Pull Requests". Having this disabled will
result in the CI job not creating new PRs as long as a branch named `obmondo-deploy` exists.

### GitLab

**TODO:** Start by documenting what these pull requests are actually all about....

kubeaid requires two CI/CD secrets to be configured in order for GitLab CI to be able to create merge requests against a
config repository:

- `KUBERNETES_CONFIG_REPO_TOKEN`: GitLab access token with permissions `api` and `read_repository`
- `KUBERNETES_CONFIG_REPO_URL`: Complete URL to target git repo, e.g.
  `https://gitlab.example.org/it/kubeaid-config-awesomecorp.git`

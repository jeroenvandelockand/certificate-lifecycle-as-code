# Architecture

## Responsibility model

| Layer | Responsibility | Declarative objects |
|---|---|---|
| GitOps | desired state and reconciliation | Argo CD `Application` |
| Governance | who may request which identities | `CertificateRequestPolicy` and RBAC |
| Lifecycle | issue, renew and rotate | `Certificate`, `CertificateRequest` |
| Issuer abstraction | select the certificate authority | `ClusterIssuer` |
| Trust | sign and validate identities | lab CA in V1; enterprise PKI later |
| Consumer | serve TLS using the generated key pair | Kubernetes Secret mounted by nginx |

Argo CD manages intent. cert-manager manages lifecycle. approver-policy manages
governance. The CA establishes trust.

## Bootstrap boundary

Four operations are intentionally imperative:

1. Create Kubernetes with Kind.
2. Install Argo CD.
3. expose a local Git snapshot when no remote repository is available.
4. Generate and load the ephemeral CA private key.

Everything after that is reconciled from Git. The CA key is the important
exception: secret key material never belongs in source control.

## Local Git design

`make local-repo` creates a clean commit in a temporary directory, clones it as
a bare repository and packages that small snapshot into a Kubernetes ConfigMap.
It builds a minimal local image containing Alpine's separate `git-daemon`
package and imports that image into the `k8s.io` containerd namespace on every
Kind node. This deliberately bypasses `kind load docker-image`, whose older
clients cannot parse node images that use containerd config version 4. An
in-cluster, read-only Git daemon exposes the repository at
`git://clac-git.argocd.svc.cluster.local/repository.git`. Before applying the
root Application, the scripts run `git ls-remote` from Argo CD's repo-server.
This avoids assumptions about a GitHub username, public repository, Docker
container IP, host gateway or host firewall.

Repository updates use a `Recreate` Deployment strategy. During bootstrap,
known transient transport errors are retried because Argo CD may have started a
comparison just before the previous ephemeral repository pod was replaced.
Configuration and manifest-generation errors remain immediately fatal.

On an existing cluster, the Application status can briefly describe the
previous source after the new spec has been applied. The bootstrap therefore
waits until `status.sync.comparedTo.source` matches the current repository URL,
revision and path before interpreting either `Synced` or `ComparisonError`.

The locally built Git server and ConfigMap are test infrastructure, not a
production pattern. The script rejects snapshots near the Kubernetes ConfigMap
size limit.

## Dependency order

The root Helm chart produces child Applications in this order:

1. cert-manager (with its built-in auto-approver disabled)
2. approver-policy
3. local CA `ClusterIssuer`
4. certificate policy and RBAC binding
5. demo workload and its `Certificate`

Argo CD sync waves express that ordering. Runtime wait scripts independently
verify readiness and produce useful timeouts if a dependency fails.

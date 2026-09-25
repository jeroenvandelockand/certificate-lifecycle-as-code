# Certificate Lifecycle as Code

A reproducible Kubernetes lab for policy-controlled certificate issuance,
consumption, renewal, key rotation and GitOps recovery.

Application teams declare certificate intent. Argo CD keeps the desired state
converged, approver-policy controls what may be requested, cert-manager owns the
lifecycle, and a local CA establishes trust.

## Quick start

Requirements:

- Linux (tested design target: Fedora and Ubuntu)
- Docker with a running daemon
- `kind`, `kubectl`, `git`, `openssl`, `curl`, `make`, `tar` and `sed`
- At least 4 GiB free memory and internet access for container images/charts

Run the complete demo:

```bash
make demo
make test
```

Inspect the certificate:

```bash
make certificate-info
```

Watch automatic renewal and key rotation (normally about six minutes after
initial issuance):

```bash
make test-renewal
```

Open Argo CD:

```bash
make argocd-password
make argocd-ui
```

Then browse to <https://localhost:8080> and sign in as `admin`.

Remove everything:

```bash
make destroy
```

## What `make demo` builds

```text
local source tree -> temporary bare Git server -> Argo CD root Application
                                                   |
                    +------------------------------+-------------------+
                    |                              |                   |
               cert-manager                approver-policy      local desired state
                    |                              |                   |
                    +------ CertificateRequest ---+                   |
                                   |                                  |
                              ephemeral CA                             |
                                   |                                  |
                              TLS Secret ----------------------> nginx workload
```

The temporary CA key is generated under the runtime directory and loaded into
a Kubernetes Secret. It is never committed to Git. An in-cluster Git service
exposes a generated snapshot only inside the Kind cluster, allowing the exact
same Argo CD flow to work before this project is pushed to GitHub.

Runtime files live in `.clac/runtime/<cluster-name>` inside the checked-out
repository. `.clac/` is ignored by Git and excluded from the snapshot served to
Argo CD. Using a repository-local directory avoids ownership collisions from
stale, globally named directories under `/tmp`. `make doctor` verifies that the
runtime directory is writable before cluster bootstrap starts.

The Git server image is built locally and imported directly into containerd on
every Kind node. This avoids a compatibility problem where older Kind clients
cannot parse containerd config version 4 while loading an image. Nothing is
pushed to a public registry.

The ephemeral Git Deployment uses a `Recreate` rollout. The root bootstrap also
retries short-lived transport errors while the repository endpoint changes;
permanent Argo CD comparison errors still stop the demo immediately.

When reusing an existing cluster, the bootstrap ignores Application status from
the previous repository source until Argo CD has compared the newly applied
repository URL, revision and path. This prevents an old `ComparisonError` from
failing a valid `make demo` run.

## How cert-manager is synchronized

The `certificate-platform` root Application reads `gitops/root` from the local
Git service. That Helm chart renders five child Applications. The child named
`cert-manager` then fetches the pinned cert-manager Helm chart directly from
`https://charts.jetstack.io` and installs it into the `cert-manager` namespace.

```text
local Git Service
  -> certificate-platform root Application
     -> cert-manager child Application
        -> charts.jetstack.io/cert-manager
           -> cert-manager namespace
```

Check every level with:

```bash
kubectl -n argocd get application certificate-platform
kubectl -n argocd get applications
kubectl -n argocd get application cert-manager -o wide
kubectl -n cert-manager get deployments,pods
```

If the root Application shows `ComparisonError`, rebuild and verify the local
bridge without recreating the cluster:

```bash
make repair-gitops
```

## Tests

| Command | Evidence |
|---|---|
| `make test-platform` | controllers, CRDs and `ClusterIssuer` are healthy |
| `make test-issuance` | SAN, issuer, chain, private key and renewal time are correct |
| `make test-tls` | nginx serves the certificate from the generated Secret |
| `make test-policy` | a request for `banking.example.com` is denied and no Secret appears |
| `make test-gitops` | Argo CD recreates a manually deleted `Certificate` |
| `make test-renewal` | serial number and private-key fingerprint both rotate |

The normal `make test` suite excludes the time-based renewal test so the fast
feedback loop stays below the intended 15-minute demo window.

## Use a GitHub repository instead of local Git

The default local flow needs no remote repository. After pushing this project,
you can point the root Application at GitHub:

```bash
make cluster argocd
REPO_URL=https://github.com/jeroenvandelockand/certificate-lifecycle-as-code.git \
  make gitops-root
make ca wait test
```

For a private repository, register repository credentials in Argo CD first.
Credentials are intentionally outside this repository.

## Push this download to GitHub

```bash
unzip certificate-lifecycle-as-code.zip
cd certificate-lifecycle-as-code
make validate
make init-git
git remote add origin git@github.com:jeroenvandelockand/certificate-lifecycle-as-code.git
git push -u origin main
```

## Scope

V1 proves the local-CA path end to end. EJBCA via ACME, the EJBCA external
issuer, trust-manager, OpenShift/ARO and workload hot reload are deliberately
kept as follow-on profiles. See [the roadmap](docs/roadmap.md).

## Documentation

- [Architecture](docs/architecture.md)
- [Repository structure](docs/repository-structure.md)
- [Certificate lifecycle](docs/lifecycle.md)
- [Security model](docs/security-model.md)
- [Roadmap](docs/roadmap.md)
- [Architecture decisions](docs/adr/)

## Important

This repository is a lab and reference implementation. The generated CA is
ephemeral and not suitable for production. Use an enterprise CA/HSM, protected
credentials, audited policy ownership, monitoring and documented recovery
procedures in real environments.

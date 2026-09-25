# Repository structure

```text
certificate-lifecycle-as-code/
├── .github/workflows/       CI rebuilds the lab on every push and PR
├── bootstrap/
│   ├── argocd/              one root Application template
│   ├── kind/                local Kubernetes cluster definition
│   └── local-git/           in-cluster Git bridge for pre-push testing
├── gitops/root/             Helm app-of-apps chart and component ordering
├── platform/pki/            issuer abstraction; no private key material
├── policies/                approval rules and their RBAC binding
├── workloads/demo-app/      Certificate plus TLS-consuming nginx workload
├── scenarios/forbidden/     negative test input, excluded from steady state
├── scripts/
│   ├── lib/                 shared environment, output and wait functions
│   └── *.sh                 bootstrap, inspection, renewal and teardown
├── tests/
│   ├── lib/                 small assertion library
│   └── *.sh                 executable acceptance tests
├── docs/adr/                architecture decision records
├── Makefile                 user-facing command interface
├── versions.env             single runtime version source
└── renovate.json            dependency update discovery
```

## Ownership boundaries

`platform/`, `policies/` and `workloads/` are deliberately separate. A real
organization can give each directory a different CODEOWNERS group without
changing the deployment model:

| Path | Typical owner |
|---|---|
| `platform/` | platform engineering / PKI integration team |
| `policies/` | security and platform governance |
| `workloads/` | application team |
| `bootstrap/` and `gitops/` | platform engineering |
| `tests/` | shared platform product team |

`scenarios/forbidden/` is not reconciled by Argo CD. The policy test applies it
temporarily, observes denial, and removes it. This keeps the steady-state Argo
CD applications Healthy while retaining a reproducible negative test.

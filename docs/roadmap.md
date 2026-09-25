# Roadmap

## V1.1 — operate renewed trust

- add trust-manager and managed CA bundles
- test nginx/application reload after Secret rotation
- expose Prometheus metrics and example alerts
- simulate issuer outage and recovery
- add CA rotation and overlapping trust bundles

## V2 — enterprise PKI profiles

Two EJBCA profiles will preserve the same workload `Certificate` API:

| Profile | Integration | Trade-off |
|---|---|---|
| `ejbca-acme` | cert-manager to EJBCA ACME | portable standard, challenge automation required |
| `ejbca-issuer` | external issuer to EJBCA REST | richer vendor integration, higher coupling |

Each profile needs explicit prerequisites, credential handling, policy mapping,
automated tests and teardown. Neither will place EJBCA credentials in Git.

## V2.1 — OpenShift and ARO

- replace Kind bootstrap with an existing-cluster profile
- add OpenShift Route and service CA comparisons
- define namespace/project ownership and SCC requirements
- document integration with enterprise ingress and external DNS


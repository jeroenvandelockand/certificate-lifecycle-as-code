# Security model

## Guarantees demonstrated by V1

- The CA private key is not stored in Git.
- Host-side runtime files are stored below the Git-ignored `.clac/` directory
  and excluded from the repository snapshot served to Argo CD.
- cert-manager's permissive built-in auto-approver is disabled.
- approver-policy limits DNS suffix, issuer, namespace, duration, usage,
  algorithm and key size.
- RBAC binds policy use only to the cert-manager controller ServiceAccount.
- The demo workload does not mount a service-account token.
- The workload runs as non-root, drops Linux capabilities and prevents
  privilege escalation.
- The local Git snapshot is read-only and reachable only through a ClusterIP
  Service inside the demo cluster.
- Component and container versions are pinned.

## Not production-ready

- The CA key is software-generated and stored in a Kubernetes Secret.
- The CA is ephemeral, has no backup, revocation service or audit integration.
- The root Argo CD project is broad and uses the default project.
- There is no network policy, external secret store, HSM or disaster recovery.
- The Git daemon endpoint is unauthenticated and unencrypted inside the local
  demo cluster.
- Monitoring, alerting, SLOs and audit retention are not configured.

For production, replace the local CA with an enterprise issuer, constrain Argo
CD projects and destinations, protect issuer credentials, audit policy changes,
monitor expiry/issuance failures and design CA plus GitOps recovery together.

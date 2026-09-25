# ADR 004: Certificate requests require explicit policy approval

Status: Accepted

cert-manager's built-in auto-approver is disabled. approver-policy evaluates
requests against a cluster-scoped policy selected by issuer and namespace.
RBAC determines which requester may use that policy.

This prevents self-service certificate issuance from becoming unrestricted
access to arbitrary identities or CA capabilities.


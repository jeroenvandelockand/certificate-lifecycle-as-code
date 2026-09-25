# ADR 003: Keep consumers independent of the PKI backend

Status: Accepted

Consumers depend on cert-manager's `Certificate` API and an issuer reference,
not on CA-specific enrollment commands. A future EJBCA ACME or external issuer
profile may replace `demo-ca` while preserving the workload consumption model.


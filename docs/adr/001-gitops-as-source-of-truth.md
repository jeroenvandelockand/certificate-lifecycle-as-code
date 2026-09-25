# ADR 001: GitOps as source of truth

Status: Accepted

Argo CD owns platform configuration, policy and workload certificate intent.
Only cluster creation, Argo CD bootstrap, local Git test infrastructure and
ephemeral CA key generation remain imperative.

This boundary keeps steady-state operations declarative while acknowledging
that Git cannot safely bootstrap itself or hold private CA keys.


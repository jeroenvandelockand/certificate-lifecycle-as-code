#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "${SCRIPT_DIR}/../scripts/lib/common.sh"
# shellcheck source=lib/test.sh
source "${SCRIPT_DIR}/lib/test.sh"

use_context
printf '\nPlatform tests\n\n'

assert_command "EXP-001 Kubernetes node is Ready" kubectl wait --for=condition=Ready nodes --all --timeout=10s
assert_command "EXP-002 Argo CD root Application exists" kubectl -n argocd get application certificate-platform

root_repo="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.spec.source.repoURL}')"
if [[ "${root_repo}" == "git://clac-git.argocd.svc.cluster.local/repository.git" || "${root_repo}" == https://* || "${root_repo}" == http://* || "${root_repo}" == ssh://* || "${root_repo}" == git@* ]]; then
  pass "EXP-003 Root Application has a valid Git repository URL"
else
  record_fail "EXP-003 Root Application has a valid Git repository URL"
fi

root_sync="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.status.sync.status}')"
if [[ "${root_sync}" == "Synced" ]]; then
  pass "EXP-004 Root Application is Synced"
else
  record_fail "EXP-004 Root Application is Synced"
fi

if [[ "${root_repo}" == "git://clac-git.argocd.svc.cluster.local/repository.git" ]]; then
  assert_command "EXP-005 local Git bridge is available" kubectl -n argocd wait --for=condition=Available deployment/clac-git-server --timeout=10s
else
  pass "EXP-005 external Git repository profile is active"
fi
assert_command "EXP-006 cert-manager child Application exists" kubectl -n argocd get application cert-manager
assert_command "EXP-007 cert-manager is available" kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager --timeout=10s
assert_command "EXP-008 approver-policy is available" kubectl -n cert-manager wait --for=condition=Available deployment/cert-manager-approver-policy --timeout=10s
assert_command "EXP-009 demo CA is Ready" kubectl wait --for=condition=Ready clusterissuer/demo-ca --timeout=10s
assert_command "EXP-010 certificate policy exists" kubectl get certificaterequestpolicy/demo-workload-certificates

finish

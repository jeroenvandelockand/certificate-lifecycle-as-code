#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
use_context

printf '\nArgo CD Applications\n'
kubectl -n argocd get applications 2>/dev/null || true
printf '\nCertificates\n'
kubectl get certificates,certificaterequests -A 2>/dev/null || true
printf '\nIssuers and policies\n'
kubectl get clusterissuer,certificaterequestpolicy 2>/dev/null || true
printf '\nDemo workload\n'
kubectl -n demo-app get deployment,pod,service 2>/dev/null || true
printf '\nLocal Git bridge\n'
kubectl -n argocd get deployment/clac-git-server service/clac-git 2>/dev/null || true

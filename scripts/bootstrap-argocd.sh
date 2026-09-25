#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
use_context

info "Installing Argo CD ${ARGOCD_VERSION}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply --server-side --force-conflicts -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" >/dev/null

for deployment in argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis argocd-repo-server argocd-server; do
  kubectl -n argocd rollout status "deployment/${deployment}" --timeout=300s >/dev/null
done
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s >/dev/null
ok "Argo CD is ready"


#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
use_context

info "Waiting for cert-manager"
wait_for_resource cert-manager deployment/cert-manager 300
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=300s >/dev/null
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=300s >/dev/null
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=300s >/dev/null

info "Waiting for approver-policy"
wait_for_resource cert-manager deployment/cert-manager-approver-policy 300
kubectl -n cert-manager rollout status deployment/cert-manager-approver-policy --timeout=300s >/dev/null

info "Waiting for policy and issuer resources"
wait_for_cluster_resource certificaterequestpolicy/demo-workload-certificates 300
wait_for_cluster_resource clusterissuer/demo-ca 300
kubectl wait --for=condition=Ready clusterissuer/demo-ca --timeout=300s >/dev/null

info "Waiting for the demo certificate and workload"
wait_for_resource demo-app certificate/demo-app 300
kubectl -n demo-app wait --for=condition=Ready certificate/demo-app --timeout=300s >/dev/null
kubectl -n demo-app rollout status deployment/demo-app --timeout=300s >/dev/null
ok "Certificate platform and demo workload are ready"


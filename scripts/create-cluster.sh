#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command docker
require_command kind
require_command kubectl
require_safe_name "${CLUSTER_NAME}"

if cluster_exists; then
  info "Kind cluster ${CLUSTER_NAME} already exists"
  use_context
else
  info "Creating Kind cluster ${CLUSTER_NAME} with ${KIND_NODE_IMAGE}"
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --image "${KIND_NODE_IMAGE}" \
    --config "${REPO_ROOT}/bootstrap/kind/cluster.yaml" \
    --wait 180s
fi

kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
ok "Kind cluster is ready"


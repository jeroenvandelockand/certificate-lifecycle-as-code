#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_safe_name "${CLUSTER_NAME}"
require_safe_runtime_dir

if command -v kind >/dev/null 2>&1 && cluster_exists; then
  info "Deleting Kind cluster ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
fi

if [[ -d "${RUNTIME_DIR}" ]]; then
  info "Removing ephemeral runtime data ${RUNTIME_DIR}"
  rm -rf -- "${RUNTIME_DIR}"
fi

ok "Demo resources removed"

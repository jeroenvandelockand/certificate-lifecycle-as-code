#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
require_command openssl
ensure_runtime_dir
use_context

info "Waiting for the cert-manager namespace"
wait_for_cluster_resource namespace/cert-manager 300

CA_DIR="${RUNTIME_DIR}/ca"
mkdir -p "${CA_DIR}"
chmod 700 "${CA_DIR}"

if [[ ! -s "${CA_DIR}/ca.key" || ! -s "${CA_DIR}/ca.crt" ]]; then
  info "Generating an ephemeral lab root CA outside Git"
  openssl req -x509 -new -nodes -newkey rsa:4096 -sha256 -days 7 \
    -keyout "${CA_DIR}/ca.key" \
    -out "${CA_DIR}/ca.crt" \
    -subj "/CN=Certificate Lifecycle Demo CA/O=Local Lab" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" >/dev/null 2>&1
  chmod 600 "${CA_DIR}/ca.key"
fi

kubectl -n cert-manager create secret tls demo-ca-key-pair \
  --cert="${CA_DIR}/ca.crt" \
  --key="${CA_DIR}/ca.key" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
ok "Ephemeral CA Secret exists only in the cluster"

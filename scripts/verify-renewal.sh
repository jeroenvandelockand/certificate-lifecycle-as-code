#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
require_command openssl
use_context

TIMEOUT="${RENEWAL_TIMEOUT_SECONDS:-600}"
INTERVAL="${RENEWAL_POLL_SECONDS:-10}"

read_secret_value() {
  local field="$1"
  kubectl -n demo-app get secret demo-app-tls -o "jsonpath={.data.${field}}" | base64 -d
}

certificate_serial() {
  read_secret_value 'tls\.crt' | openssl x509 -noout -serial | cut -d= -f2
}

key_fingerprint() {
  read_secret_value 'tls\.key' | openssl pkey -pubout 2>/dev/null | sha256sum | awk '{print $1}'
}

initial_serial="$(certificate_serial)"
initial_key="$(key_fingerprint)"
renewal_time="$(kubectl -n demo-app get certificate demo-app -o jsonpath='{.status.renewalTime}')"

info "Initial serial: ${initial_serial}"
info "Initial key:    ${initial_key}"
info "Renewal time:   ${renewal_time}"
info "Waiting up to ${TIMEOUT}s for automatic renewal"

elapsed=0
while (( elapsed < TIMEOUT )); do
  sleep "${INTERVAL}"
  elapsed=$((elapsed + INTERVAL))
  current_serial="$(certificate_serial)"
  current_key="$(key_fingerprint)"
  printf '[%4ss] serial=%s key=%s\n' "${elapsed}" "${current_serial:0:16}" "${current_key:0:16}"
  if [[ "${current_serial}" != "${initial_serial}" && "${current_key}" != "${initial_key}" ]]; then
    ok "Certificate renewed and private key rotated"
    exit 0
  fi
done

fail "No certificate and key rotation observed within ${TIMEOUT}s"


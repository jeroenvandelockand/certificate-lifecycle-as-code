#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "${SCRIPT_DIR}/../scripts/lib/common.sh"
# shellcheck source=lib/test.sh
source "${SCRIPT_DIR}/lib/test.sh"

use_context
require_command curl
ensure_runtime_dir
PORT="${TLS_TEST_PORT:-10443}"
LOG_FILE="${RUNTIME_DIR}/port-forward.log"

printf '\nTLS consumption test\n\n'
kubectl -n demo-app port-forward service/demo-app "${PORT}:443" >"${LOG_FILE}" 2>&1 &
pf_pid=$!
trap 'kill "${pf_pid}" >/dev/null 2>&1 || true; wait "${pf_pid}" 2>/dev/null || true' EXIT

response=""
for _ in $(seq 1 30); do
  if response="$(curl -ksS --noproxy '*' --max-time 2 --resolve "demo.apps.demo.internal:${PORT}:127.0.0.1" "https://demo.apps.demo.internal:${PORT}/" 2>/dev/null)"; then
    break
  fi
  sleep 1
done

if [[ "${response}" == "Certificate Lifecycle as Code" ]]; then
  pass "EXP-020 Workload serves HTTPS with the issued Secret"
else
  record_fail "EXP-020 Workload serves HTTPS with the issued Secret"
  [[ -f "${LOG_FILE}" ]] && sed -n '1,40p' "${LOG_FILE}" >&2
fi

finish

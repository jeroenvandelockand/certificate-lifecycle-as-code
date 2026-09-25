#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "${SCRIPT_DIR}/../scripts/lib/common.sh"
# shellcheck source=lib/test.sh
source "${SCRIPT_DIR}/lib/test.sh"

use_context
printf '\nGitOps self-healing test\n\n'

old_uid="$(kubectl -n demo-app get certificate demo-app -o jsonpath='{.metadata.uid}')"
kubectl -n demo-app delete certificate demo-app --wait=true >/dev/null

new_uid=""
for _ in $(seq 1 120); do
  new_uid="$(kubectl -n demo-app get certificate demo-app -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
  [[ -n "${new_uid}" && "${new_uid}" != "${old_uid}" ]] && break
  sleep 1
done

if [[ -n "${new_uid}" && "${new_uid}" != "${old_uid}" ]]; then
  pass "EXP-040 Argo CD recreated the deleted Certificate"
else
  record_fail "EXP-040 Argo CD recreated the deleted Certificate"
  finish
  exit $?
fi

if kubectl -n demo-app wait --for=condition=Ready certificate/demo-app --timeout=180s >/dev/null 2>&1; then
  pass "EXP-041 Recreated Certificate is Ready"
else
  record_fail "EXP-041 Recreated Certificate is Ready"
fi

finish


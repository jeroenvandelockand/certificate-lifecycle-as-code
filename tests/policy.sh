#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "${SCRIPT_DIR}/../scripts/lib/common.sh"
# shellcheck source=lib/test.sh
source "${SCRIPT_DIR}/lib/test.sh"

use_context
cleanup() {
  kubectl -n demo-app delete certificate forbidden-certificate --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl -n demo-app delete secret forbidden-tls --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

printf '\nPolicy denial test\n\n'
kubectl apply -k "${REPO_ROOT}/scenarios/forbidden" >/dev/null

request=""
for _ in $(seq 1 60); do
  request="$(kubectl -n demo-app get certificaterequests -o name 2>/dev/null | sed 's#certificaterequest.cert-manager.io/##' | awk '/^forbidden-certificate-/{print; exit}')"
  [[ -n "${request}" ]] && break
  sleep 1
done

if [[ -n "${request}" ]]; then
  pass "EXP-030 Forbidden CertificateRequest was created"
else
  record_fail "EXP-030 Forbidden CertificateRequest was created"
  finish
  exit $?
fi

denied=""
for _ in $(seq 1 60); do
  denied="$(kubectl -n demo-app get certificaterequest "${request}" -o jsonpath='{.status.conditions[?(@.type=="Denied")].status}' 2>/dev/null || true)"
  [[ "${denied}" == "True" ]] && break
  sleep 1
done

if [[ "${denied}" == "True" ]]; then
  pass "EXP-031 Forbidden DNS request is Denied"
else
  record_fail "EXP-031 Forbidden DNS request is Denied"
fi

if ! kubectl -n demo-app get secret forbidden-tls >/dev/null 2>&1; then
  pass "EXP-032 No TLS Secret was issued"
else
  record_fail "EXP-032 No TLS Secret was issued"
fi

finish


#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
source "${SCRIPT_DIR}/../scripts/lib/common.sh"
# shellcheck source=lib/test.sh
source "${SCRIPT_DIR}/lib/test.sh"

use_context
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT

printf '\nIssuance tests\n\n'

assert_command "EXP-010 Certificate is Ready" kubectl -n demo-app wait --for=condition=Ready certificate/demo-app --timeout=10s

if kubectl -n demo-app get secret demo-app-tls >/dev/null 2>&1; then
  pass "EXP-011 TLS Secret exists"
else
  record_fail "EXP-011 TLS Secret exists"
  finish
  exit $?
fi

kubectl -n demo-app get secret demo-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > "${TMP_DIR}/tls.crt"
kubectl -n demo-app get secret demo-app-tls -o jsonpath='{.data.tls\.key}' | base64 -d > "${TMP_DIR}/tls.key"
kubectl -n demo-app get secret demo-app-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > "${TMP_DIR}/ca.crt"

if openssl x509 -in "${TMP_DIR}/tls.crt" -noout -ext subjectAltName | grep -Fq 'DNS:demo.apps.demo.internal'; then
  pass "EXP-012 Expected DNS SAN is present"
else
  record_fail "EXP-012 Expected DNS SAN is present"
fi

if openssl x509 -in "${TMP_DIR}/tls.crt" -noout -issuer | grep -Fq 'Certificate Lifecycle Demo CA'; then
  pass "EXP-013 Expected issuer signed the certificate"
else
  record_fail "EXP-013 Expected issuer signed the certificate"
fi

assert_command "EXP-014 Certificate chain verifies" openssl verify -CAfile "${TMP_DIR}/ca.crt" "${TMP_DIR}/tls.crt"

cert_pub="$(openssl x509 -in "${TMP_DIR}/tls.crt" -pubkey -noout | sha256sum | awk '{print $1}')"
key_pub="$(openssl pkey -in "${TMP_DIR}/tls.key" -pubout 2>/dev/null | sha256sum | awk '{print $1}')"
if [[ "${cert_pub}" == "${key_pub}" ]]; then
  pass "EXP-015 Private key matches certificate"
else
  record_fail "EXP-015 Private key matches certificate"
fi

if [[ -n "$(kubectl -n demo-app get certificate demo-app -o jsonpath='{.status.renewalTime}')" ]]; then
  pass "EXP-016 Automatic renewal is scheduled"
else
  record_fail "EXP-016 Automatic renewal is scheduled"
fi

finish


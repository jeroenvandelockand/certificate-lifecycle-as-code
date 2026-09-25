#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
require_command openssl
require_command sha256sum
use_context

TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT

kubectl -n demo-app get secret demo-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > "${TMP_DIR}/tls.crt"
kubectl -n demo-app get secret demo-app-tls -o jsonpath='{.data.tls\.key}' | base64 -d > "${TMP_DIR}/tls.key"

serial="$(openssl x509 -in "${TMP_DIR}/tls.crt" -noout -serial | cut -d= -f2)"
subject="$(openssl x509 -in "${TMP_DIR}/tls.crt" -noout -subject | sed 's/^subject=//')"
issuer="$(openssl x509 -in "${TMP_DIR}/tls.crt" -noout -issuer | sed 's/^issuer=//')"
not_before="$(openssl x509 -in "${TMP_DIR}/tls.crt" -noout -startdate | cut -d= -f2-)"
not_after="$(openssl x509 -in "${TMP_DIR}/tls.crt" -noout -enddate | cut -d= -f2-)"
key_hash="$(openssl pkey -in "${TMP_DIR}/tls.key" -pubout 2>/dev/null | sha256sum | awk '{print $1}')"
renewal_time="$(kubectl -n demo-app get certificate demo-app -o jsonpath='{.status.renewalTime}')"

printf 'Serial:       %s\n' "${serial}"
printf 'Subject:      %s\n' "${subject}"
printf 'Issuer:       %s\n' "${issuer}"
printf 'Not Before:   %s\n' "${not_before}"
printf 'Not After:    %s\n' "${not_after}"
printf 'Renewal Time: %s\n' "${renewal_time}"
printf 'Private Key:  %s\n' "${key_hash}"


#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf '\nCertificate Lifecycle fast integration suite\n'
"${SCRIPT_DIR}/platform.sh"
"${SCRIPT_DIR}/issuance.sh"
"${SCRIPT_DIR}/tls.sh"
"${SCRIPT_DIR}/policy.sh"
"${SCRIPT_DIR}/gitops.sh"
printf '\nFast integration suite passed\n\n'


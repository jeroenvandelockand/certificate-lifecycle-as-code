#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command curl
require_command sha256sum

TOOLS_DIR="${REPO_ROOT}/.tools/bin"
mkdir -p "${TOOLS_DIR}"
arch="$(uname -m)"
case "${arch}" in
  x86_64) binary_arch=amd64 ;;
  aarch64|arm64) binary_arch=arm64 ;;
  *) fail "Unsupported architecture: ${arch}" ;;
esac

install_kind() {
  local url="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${binary_arch}"
  curl -fsSLo "${TOOLS_DIR}/kind" "${url}"
  curl -fsSL "${url}.sha256" | awk '{print $1 "  '"${TOOLS_DIR}"'/kind"}' | sha256sum -c -
  chmod +x "${TOOLS_DIR}/kind"
}

install_kubectl() {
  local base="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${binary_arch}/kubectl"
  curl -fsSLo "${TOOLS_DIR}/kubectl" "${base}"
  printf '%s  %s\n' "$(curl -fsSL "${base}.sha256")" "${TOOLS_DIR}/kubectl" | sha256sum -c -
  chmod +x "${TOOLS_DIR}/kubectl"
}

install_kind
install_kubectl

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "${TOOLS_DIR}" >> "${GITHUB_PATH}"
fi
ok "CI tools installed in ${TOOLS_DIR}"


#!/usr/bin/env bash

set -Eeuo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/versions.env"

CLUSTER_NAME="${CLUSTER_NAME:-clac-demo}"
DEFAULT_RUNTIME_DIR="${REPO_ROOT}/.clac/runtime/${CLUSTER_NAME}"
RUNTIME_DIR="${CLAC_RUNTIME_DIR:-${DEFAULT_RUNTIME_DIR}}"

export REPO_ROOT CLUSTER_NAME DEFAULT_RUNTIME_DIR RUNTIME_DIR

color_enabled() {
  [[ -t 1 && "${NO_COLOR:-}" == "" ]]
}

info() {
  if color_enabled; then printf '\033[1;34m==>\033[0m %s\n' "$*"; else printf '==> %s\n' "$*"; fi
}

ok() {
  if color_enabled; then printf '\033[1;32m[OK]\033[0m %s\n' "$*"; else printf '[OK] %s\n' "$*"; fi
}

fail() {
  if color_enabled; then printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; else printf '[FAIL] %s\n' "$*" >&2; fi
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_safe_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,40}$ ]] || fail "Unsafe name: $1"
}

require_safe_runtime_dir() {
  local runtime_basename
  [[ "${RUNTIME_DIR}" == /* ]] || fail "Runtime path must be absolute: ${RUNTIME_DIR}"

  if [[ -n "${CLAC_RUNTIME_DIR:-}" ]]; then
    runtime_basename="${RUNTIME_DIR##*/}"
    [[ "${runtime_basename}" == certificate-lifecycle-as-code-* ]] \
      || fail "Custom runtime directory must end in certificate-lifecycle-as-code-*: ${RUNTIME_DIR}"
  else
    [[ "${RUNTIME_DIR}" == "${DEFAULT_RUNTIME_DIR}" ]] \
      || fail "Unexpected default runtime directory: ${RUNTIME_DIR}"
  fi
}

ensure_runtime_dir() {
  require_safe_runtime_dir
  mkdir -p "${RUNTIME_DIR}" \
    || fail "Cannot create runtime directory ${RUNTIME_DIR}. Check ownership and permissions."
  [[ -w "${RUNTIME_DIR}" ]] \
    || fail "Runtime directory is not writable: ${RUNTIME_DIR}"
}

cluster_exists() {
  kind get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"
}

use_context() {
  kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null
}

wait_for_resource() {
  local namespace="$1" resource="$2" timeout="${3:-300}"
  local elapsed=0
  until kubectl get -n "${namespace}" "${resource}" >/dev/null 2>&1; do
    (( elapsed >= timeout )) && fail "Timed out waiting for ${namespace}/${resource}"
    sleep 2
    elapsed=$((elapsed + 2))
  done
}

wait_for_cluster_resource() {
  local resource="$1" timeout="${2:-300}"
  local elapsed=0
  until kubectl get "${resource}" >/dev/null 2>&1; do
    (( elapsed >= timeout )) && fail "Timed out waiting for ${resource}"
    sleep 2
    elapsed=$((elapsed + 2))
  done
}

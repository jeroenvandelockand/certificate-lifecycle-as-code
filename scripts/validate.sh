#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

info "Checking shell syntax"
while IFS= read -r script; do
  bash -n "${script}"
done < <(find "${REPO_ROOT}/scripts" "${REPO_ROOT}/tests" -type f -name '*.sh' | sort)

info "Checking Kustomize resource references"
while IFS= read -r kustomization; do
  directory="$(dirname "${kustomization}")"
  while IFS= read -r resource; do
    [[ -e "${directory}/${resource}" ]] || fail "Missing ${resource} referenced by ${kustomization}"
  done < <(awk '/^resources:/{in_resources=1; next} in_resources && /^[^ ]/{in_resources=0} in_resources && /^  - /{sub(/^  - /, ""); print}' "${kustomization}")
done < <(find "${REPO_ROOT}" -name kustomization.yaml -type f | sort)

info "Checking required repository files"
for path in README.md Makefile versions.env bootstrap/argocd/root-application.yaml.tpl bootstrap/local-git/server.yaml.tpl gitops/root/Chart.yaml tests/all.sh; do
  [[ -f "${REPO_ROOT}/${path}" ]] || fail "Missing required file: ${path}"
done

ok "Offline validation passed"

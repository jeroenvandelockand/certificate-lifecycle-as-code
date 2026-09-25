#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git

if [[ -d "${REPO_ROOT}/.git" ]]; then
  info "Git repository already initialized"
else
  git -C "${REPO_ROOT}" init -b main
fi

if ! git -C "${REPO_ROOT}" config user.name >/dev/null; then
  git -C "${REPO_ROOT}" config user.name "Jeroen van de Lockand"
fi
if ! git -C "${REPO_ROOT}" config user.email >/dev/null; then
  git -C "${REPO_ROOT}" config user.email "jeroen@users.noreply.github.com"
fi

git -C "${REPO_ROOT}" add .
if git -C "${REPO_ROOT}" diff --cached --quiet; then
  info "No changes to commit"
else
  git -C "${REPO_ROOT}" commit -m "Initial Certificate Lifecycle as Code demo"
fi
ok "Repository is ready; add a remote and push main"

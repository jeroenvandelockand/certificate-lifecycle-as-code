#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command kubectl
require_command sed
ensure_runtime_dir
use_context

TARGET_REVISION="${TARGET_REVISION:-main}"
if [[ -n "${REPO_URL:-}" ]]; then
  EFFECTIVE_REPO_URL="${REPO_URL}"
elif [[ -f "${RUNTIME_DIR}/repo-url" ]]; then
  EFFECTIVE_REPO_URL="$(<"${RUNTIME_DIR}/repo-url")"
else
  fail "No REPO_URL supplied and no local repository exists. Run make local-repo first."
fi

[[ "${EFFECTIVE_REPO_URL}" != *[[:space:]]* ]] || fail "Repository URL contains whitespace: ${EFFECTIVE_REPO_URL}"
case "${EFFECTIVE_REPO_URL}" in
  git://*|https://*|http://*|ssh://*|git@*) ;;
  *) fail "Unsupported repository URL: ${EFFECTIVE_REPO_URL}" ;;
esac

if [[ "${EFFECTIVE_REPO_URL}" == git://clac-git.argocd.svc.cluster.local/* ]]; then
  info "Verifying the local repository from Argo CD"
  kubectl -n argocd exec deployment/argocd-repo-server -- \
    git ls-remote "${EFFECTIVE_REPO_URL}" "refs/heads/${TARGET_REVISION}" >/dev/null \
    || fail "Argo CD cannot read ${TARGET_REVISION} from ${EFFECTIVE_REPO_URL}"
fi

ROOT_APP="${RUNTIME_DIR}/root-application.yaml"

sed \
  -e "s|__REPO_URL__|${EFFECTIVE_REPO_URL}|g" \
  -e "s|__TARGET_REVISION__|${TARGET_REVISION}|g" \
  -e "s|__CERT_MANAGER_VERSION__|${CERT_MANAGER_VERSION}|g" \
  -e "s|__APPROVER_POLICY_VERSION__|${APPROVER_POLICY_VERSION}|g" \
  -e "s|__DEMO_APP_IMAGE__|${DEMO_APP_IMAGE}|g" \
  "${REPO_ROOT}/bootstrap/argocd/root-application.yaml.tpl" > "${ROOT_APP}"

info "Applying Argo CD root Application from ${EFFECTIVE_REPO_URL}"
kubectl apply -f "${ROOT_APP}" >/dev/null

applied_repo_url="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.spec.source.repoURL}')"
applied_revision="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.spec.source.targetRevision}')"
applied_path="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.spec.source.path}')"

[[ "${applied_repo_url}" == "${EFFECTIVE_REPO_URL}" ]] \
  || fail "Root Application repository was not updated: ${applied_repo_url}"
[[ "${applied_revision}" == "${TARGET_REVISION}" ]] \
  || fail "Root Application revision was not updated: ${applied_revision}"
[[ "${applied_path}" == "gitops/root" ]] \
  || fail "Root Application path was not updated: ${applied_path}"

# An existing cluster can still contain conditions from a previous Application
# generation. Request a new comparison and only evaluate status after
# status.sync.comparedTo describes the source applied above.
kubectl -n argocd annotate application certificate-platform \
  argocd.argoproj.io/refresh=hard --overwrite >/dev/null

info "Waiting for the root Application to load and sync"
transient_comparison_reported=false
stale_status_reported=false
last_condition_message=""
for _ in $(seq 1 90); do
  compared_repo_url="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.status.sync.comparedTo.source.repoURL}' 2>/dev/null || true)"
  compared_revision="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.status.sync.comparedTo.source.targetRevision}' 2>/dev/null || true)"
  compared_path="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.status.sync.comparedTo.source.path}' 2>/dev/null || true)"

  if [[ "${compared_repo_url}" != "${EFFECTIVE_REPO_URL}" \
    || "${compared_revision}" != "${TARGET_REVISION}" \
    || "${compared_path}" != "gitops/root" ]]; then
    if [[ "${stale_status_reported}" == false ]]; then
      info "Ignoring status from the previous root Application source while Argo CD refreshes"
      stale_status_reported=true
    fi
    sleep 2
    continue
  fi

  condition_types="$(kubectl -n argocd get application certificate-platform -o jsonpath='{range .status.conditions[*]}{.type}{"\n"}{end}' 2>/dev/null || true)"
  condition_message="$(kubectl -n argocd get application certificate-platform -o jsonpath='{range .status.conditions[?(@.type=="ComparisonError")]}{.message}{end}' 2>/dev/null || true)"
  sync_status="$(kubectl -n argocd get application certificate-platform -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  if [[ "${sync_status}" == "Synced" ]]; then
    ok "Root Application is Synced"
    exit 0
  fi

  if grep -Fxq "ComparisonError" <<< "${condition_types}"; then
    last_condition_message="${condition_message}"
    if grep -Eiq 'unexpected EOF|connection reset by peer|connection refused|server closed idle connection|i/o timeout|context deadline exceeded' <<< "${condition_message}"; then
      if [[ "${transient_comparison_reported}" == false ]]; then
        info "Argo CD reported a temporary Git transport error; waiting for its automatic retry"
        transient_comparison_reported=true
      fi
    else
      fail "Argo CD comparison failed: ${condition_message}"
    fi
  fi
  sleep 2
done

kubectl -n argocd get application certificate-platform -o yaml >&2 || true
kubectl -n argocd logs deployment/argocd-repo-server --tail=100 >&2 || true
kubectl -n argocd logs deployment/clac-git-server -c git-daemon --tail=100 >&2 || true
if [[ -n "${last_condition_message}" ]]; then
  fail "Root Application did not become Synced within 180 seconds. Last comparison error: ${last_condition_message}"
fi
fail "Root Application did not become Synced within 180 seconds"

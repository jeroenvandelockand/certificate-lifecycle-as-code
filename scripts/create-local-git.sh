#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git
require_command tar
require_command kubectl
require_command sed
require_command docker
require_command kind
require_safe_name "${CLUSTER_NAME}"
ensure_runtime_dir
cluster_exists || fail "Kind cluster ${CLUSTER_NAME} does not exist"
use_context

GIT_RUNTIME_DIR="${RUNTIME_DIR}/git"
SNAPSHOT_DIR="${GIT_RUNTIME_DIR}/snapshot"
BARE_DIR="${GIT_RUNTIME_DIR}/repository.git"
ARCHIVE="${GIT_RUNTIME_DIR}/repository.tar.gz"
SERVER_MANIFEST="${GIT_RUNTIME_DIR}/server.yaml"
IMAGE_ARCHIVE="${GIT_RUNTIME_DIR}/git-server-image.tar"
LOCAL_REPO_URL="git://clac-git.argocd.svc.cluster.local/repository.git"

[[ "${GIT_RUNTIME_DIR}" == "${RUNTIME_DIR}/git" ]] \
  || fail "Refusing to recreate unexpected runtime path: ${GIT_RUNTIME_DIR}"

info "Creating a clean Git snapshot for Argo CD"
rm -rf -- "${GIT_RUNTIME_DIR}"
mkdir -p "${SNAPSHOT_DIR}"

tar \
  --exclude='./.git' \
  --exclude='./.clac' \
  --exclude='./.tools' \
  --exclude='./*.zip' \
  -C "${REPO_ROOT}" -cf - . | tar -C "${SNAPSHOT_DIR}" -xf -

git -C "${SNAPSHOT_DIR}" init -b main >/dev/null
git -C "${SNAPSHOT_DIR}" config user.name "Certificate Lifecycle Demo"
git -C "${SNAPSHOT_DIR}" config user.email "demo@localhost"
git -C "${SNAPSHOT_DIR}" add .
git -C "${SNAPSHOT_DIR}" commit -m "Local demo snapshot" >/dev/null
git clone --bare "${SNAPSHOT_DIR}" "${BARE_DIR}" >/dev/null 2>&1
touch "${BARE_DIR}/git-daemon-export-ok"
tar -C "${GIT_RUNTIME_DIR}" -czf "${ARCHIVE}" repository.git

archive_size="$(wc -c < "${ARCHIVE}")"
(( archive_size < 800000 )) || fail "Local Git snapshot is too large for a ConfigMap (${archive_size} bytes)"

info "Building the local Git server image"
docker build --pull \
  --tag "${LOCAL_GIT_SERVER_IMAGE}" \
  --file "${REPO_ROOT}/bootstrap/local-git/Dockerfile" \
  "${REPO_ROOT}/bootstrap/local-git"

docker run --rm --entrypoint /bin/sh "${LOCAL_GIT_SERVER_IMAGE}" -ec \
  'test -x "$(git --exec-path)/git-daemon"' \
  || fail "The local image does not contain the git-daemon executable"

info "Importing the local Git server image into Kind's containerd"
# `kind load docker-image` parses containerd's config before loading. Older
# Kind clients only understand config versions 2 and 3, while newer Kubernetes
# node images can use version 4. Importing through ctr talks directly to the
# running containerd daemon and therefore works with either configuration.
docker image save --output "${IMAGE_ARCHIVE}" "${LOCAL_GIT_SERVER_IMAGE}"

mapfile -t kind_nodes < <(kind get nodes --name "${CLUSTER_NAME}")
(( ${#kind_nodes[@]} > 0 )) || fail "No nodes found for Kind cluster ${CLUSTER_NAME}"

for kind_node in "${kind_nodes[@]}"; do
  info "Importing ${LOCAL_GIT_SERVER_IMAGE} into ${kind_node}"
  docker exec -i "${kind_node}" \
    ctr --namespace k8s.io images import - < "${IMAGE_ARCHIVE}" >/dev/null \
    || fail "Could not import ${LOCAL_GIT_SERVER_IMAGE} into ${kind_node}"

  docker exec "${kind_node}" \
    ctr --namespace k8s.io images list --quiet |
    grep -Fq "${LOCAL_GIT_SERVER_IMAGE}" \
    || fail "Imported image is not visible in ${kind_node}'s k8s.io namespace"
done

info "Loading the Git snapshot into the cluster"
kubectl -n argocd create configmap clac-git-repository \
  --from-file="repository.tar.gz=${ARCHIVE}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

sed "s|__LOCAL_GIT_SERVER_IMAGE__|${LOCAL_GIT_SERVER_IMAGE}|g" \
  "${REPO_ROOT}/bootstrap/local-git/server.yaml.tpl" > "${SERVER_MANIFEST}"
kubectl apply -f "${SERVER_MANIFEST}" >/dev/null

# A stable ConfigMap name does not change the pod template. Restart on every
# snapshot update so the init container unpacks the latest commit.
kubectl -n argocd rollout restart deployment/clac-git-server >/dev/null
if ! kubectl -n argocd rollout status deployment/clac-git-server --timeout=180s; then
  kubectl -n argocd get pods -l app.kubernetes.io/name=clac-git-server -o wide >&2 || true
  kubectl -n argocd describe pods -l app.kubernetes.io/name=clac-git-server >&2 || true
  kubectl -n argocd logs -l app.kubernetes.io/name=clac-git-server -c unpack-repository --tail=50 >&2 || true
  kubectl -n argocd logs -l app.kubernetes.io/name=clac-git-server -c git-daemon --tail=50 >&2 || true
  fail "Local Git server did not become ready"
fi

info "Testing Git access from the Argo CD repo-server"
if ! kubectl -n argocd exec deployment/argocd-repo-server -- \
  git ls-remote "${LOCAL_REPO_URL}" refs/heads/main >/dev/null; then
  kubectl -n argocd logs deployment/clac-git-server -c git-daemon --tail=50 >&2 || true
  fail "Argo CD cannot reach ${LOCAL_REPO_URL}"
fi

printf '%s\n' "${LOCAL_REPO_URL}" > "${RUNTIME_DIR}/repo-url"
ok "Argo CD can read the local Git snapshot at ${LOCAL_REPO_URL}"

# Changelog

## 2026-09-25 — User-owned runtime directory

- move generated runtime data from the globally named `/tmp` directory to
  `.clac/runtime/<cluster-name>` in the current repository
- prevent permission failures when an earlier run created the shared `/tmp`
  path as root or another user
- centralize runtime-path safety and writability checks
- make `make doctor` fail early with the exact unwritable path
- keep `.clac/` Git-ignored and excluded from the local Argo CD snapshot
- retain a guarded `CLAC_RUNTIME_DIR` override for advanced use

## 2026-09-25 — Stale Argo CD status protection

- verify the live root Application spec immediately after `kubectl apply`
- request a hard refresh for every root Application bootstrap
- compare `.status.sync.comparedTo.source` with the repository, revision and
  path that were just applied
- ignore `Synced` and `ComparisonError` values left over from a previous root
  Application source
- fix first-run failures that incorrectly reported the historical
  `git://invalid IP/repository.git` URL and only recovered on
  `make repair-gitops`

## 2026-09-23 — Git rollout race handling

- use the `Recreate` Deployment strategy for the ephemeral Git server so Argo
  CD cannot retain a connection to a terminating repository pod
- treat known short-lived Git transport failures such as `unexpected EOF` as
  retryable during root Application reconciliation
- request one hard refresh and keep waiting up to the existing 180-second
  deadline
- preserve fail-fast behavior for permanent comparison errors such as an
  invalid path, invalid URL or missing revision
- print repo-server and Git daemon logs when transient failures do not recover

## 2026-09-22 — Containerd v4-compatible image loading

- replaced `kind load docker-image` with a direct `ctr` import into every Kind
  node
- avoid the older Kind client's containerd configuration parser, which rejects
  node images using containerd config version 4
- verify the imported image in containerd's `k8s.io` namespace before applying
  the local Git server Deployment

## 2026-09-22 — Native Git protocol image

- replaced dumb HTTP because Argo CD's repository client returned
  `unexpected EOF` even though command-line `git ls-remote` succeeded
- added a minimal locally built Alpine image with the separate `git-daemon`
  package
- load the local image directly into Kind and use `imagePullPolicy: Never`
- run both snapshot extraction and the Git daemon as UID/GID `65532`
- restored the native `git://` protocol behind the stable ClusterIP Service

## 2026-09-22 — Portable local Git server

- replaced `git daemon` because the pinned `alpine/git` image does not ship the
  separate `git-daemon` executable
- generate dumb-HTTP metadata with `git update-server-info`
- serve the bare repository read-only with pinned BusyBox `httpd`
- print pod descriptions and both container logs automatically on rollout
  failure

## 2026-09-22 — Local Git bridge fix

- replaced Docker container-IP discovery with an in-cluster Git Deployment and
  stable ClusterIP Service
- added an end-to-end `git ls-remote` check from the Argo CD repo-server
- reject repository URLs containing whitespace before applying them
- fail fast when the root Application reports an Argo CD `ComparisonError`
- added `make repair-gitops` for repairing an existing demo cluster
- extended platform tests to verify the root repository URL, sync status, local
  Git bridge and cert-manager child Application

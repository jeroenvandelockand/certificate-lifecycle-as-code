#!/usr/bin/env bash

set -Eeuo pipefail

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
  printf 'PASS  %s\n' "$*"
}

record_fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$*" >&2
}

assert_command() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "${description}"; else record_fail "${description}"; fi
}

finish() {
  printf '\n%d passed, %d failed\n' "${pass_count}" "${fail_count}"
  (( fail_count == 0 ))
}


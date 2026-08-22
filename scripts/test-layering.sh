#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
checker="$script_dir/check-layering.sh"
fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/nami-layering.XXXXXX")
source_root="$fixture_dir/nami"

cleanup() {
  rm -rf -- "$fixture_dir"
}
trap cleanup EXIT

write_valid_fixture() {
  rm -rf -- "$source_root"
  mkdir -p "$source_root/spectral"
  printf '%s\n' 'from std.collections import List' >"$source_root/elementary.mojo"
  printf '%s\n' 'from shuhafft import RealFFTPlan' >"$source_root/spectral/adapter.mojo"
}

expect_success() {
  if ! "$@" >/dev/null 2>&1; then
    echo "expected layering check to pass: $*" >&2
    exit 1
  fi
}

expect_status() {
  expected_status=$1
  shift
  set +e
  "$@" >/dev/null 2>&1
  status=$?
  set -e
  if [[ $status -ne $expected_status ]]; then
    echo "expected status $expected_status, got $status: $*" >&2
    exit 1
  fi
}

# The forbidden-import scan returns grep status 1 here, while the explicit
# adapter scan returns 0. Both are normal results and the boundary passes.
write_valid_fixture
expect_success bash "$checker" "$source_root"

# A normal no-match from the adapter scan is a contract failure, not a scan
# error and not a false pass.
printf '%s\n' 'from std.collections import List' >"$source_root/spectral/adapter.mojo"
expect_status 1 bash "$checker" "$source_root"

# Exercise an alternate Mojo module import form that must remain spectral-only.
write_valid_fixture
printf '%s\n' 'import nami.spectral' >"$source_root/forbidden.mojo"
expect_status 1 bash "$checker" "$source_root"

# A missing grep executable produces status 127. The checker must propagate the
# scan failure instead of treating it as the ordinary no-match status 1.
write_valid_fixture
expect_status 127 env GREP_BIN="$fixture_dir/missing-grep" bash "$checker" "$source_root"

echo "Nami layering guard self-tests passed."

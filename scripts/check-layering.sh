#!/usr/bin/env bash

set -euo pipefail

source_root=${1:-src/nami}
grep_bin=${GREP_BIN:-grep}
forbidden_import_pattern='^[[:space:]]*((from|import)[[:space:]]+(shuhafft|[.]+spectral|nami[.]spectral)([.[:space:]]|$)|from[[:space:]]+([.]+|nami)[[:space:]]+import[[:space:]].*spectral)'
shuhafft_import_pattern='^[[:space:]]*(from|import)[[:space:]]+shuhafft([.[:space:]]|$)'

if [[ ! -d "$source_root" ]]; then
  echo "Nami source root does not exist or is not a directory: $source_root" >&2
  exit 2
fi

set +e
violations=$(
  "$grep_bin" -RnE \
    --include='*.mojo' \
    --exclude-dir=spectral \
    "$forbidden_import_pattern" \
    "$source_root"
)
violation_status=$?
set -e

if [[ $violation_status -gt 1 ]]; then
  echo "elementary import scan failed with status $violation_status" >&2
  exit "$violation_status"
fi

if [[ $violation_status -eq 0 ]]; then
  echo "elementary Nami modules must not import ShuhaFFT or nami.spectral:" >&2
  echo "$violations" >&2
  exit 1
fi

set +e
"$grep_bin" -RlE \
  --include='*.mojo' \
  "$shuhafft_import_pattern" \
  "$source_root/spectral" >/dev/null
spectral_status=$?
set -e

if [[ $spectral_status -gt 1 ]]; then
  echo "spectral adapter import scan failed with status $spectral_status" >&2
  exit "$spectral_status"
fi

if [[ $spectral_status -eq 1 ]]; then
  echo "nami.spectral must retain an explicit ShuhaFFT adapter import" >&2
  exit 1
fi

echo "Nami source-layer dependency boundary passed."

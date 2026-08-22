#!/usr/bin/env bash

set -euo pipefail

violations=$(
  grep -RnE \
    '^[[:space:]]*(from[[:space:]]+shuhafft|import[[:space:]]+shuhafft|from[[:space:]]+[.]+spectral|from[[:space:]]+nami[.]spectral)' \
    src/nami \
    --include='*.mojo' \
    --exclude-dir=spectral || true
)

if [[ -n "$violations" ]]; then
  echo "elementary Nami modules must not import ShuhaFFT or nami.spectral:" >&2
  echo "$violations" >&2
  exit 1
fi

spectral_imports=$(
  grep -RlE \
    '^[[:space:]]*(from[[:space:]]+shuhafft|import[[:space:]]+shuhafft)' \
    src/nami/spectral \
    --include='*.mojo' || true
)

if [[ -z "$spectral_imports" ]]; then
  echo "nami.spectral must retain an explicit ShuhaFFT adapter import" >&2
  exit 1
fi

echo "Nami source-layer dependency boundary passed."

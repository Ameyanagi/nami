#!/usr/bin/env bash
set -euo pipefail

for test_file in tests/test_*.mojo; do
  mojo run -I src "$test_file"
done

mkdir -p .pixi/test-bin
for example in examples/*.mojo; do
  example_name="$(basename "$example" .mojo)"
  mojo build -I src "$example" -o ".pixi/test-bin/$example_name"
done

#!/usr/bin/env bash
set -euo pipefail

snippet_dir=".pixi/readme-snippets"
rm -rf "$snippet_dir"
mkdir -p "$snippet_dir"

snippet_count="$(
  awk -v output_dir="$snippet_dir" '
    BEGIN {
      count = 0
      in_mojo = 0
    }

    /^```mojo[[:space:]]*$/ {
      count++
      output_file = sprintf("%s/snippet-%02d.mojo", output_dir, count)
      in_mojo = 1
      next
    }

    in_mojo && /^```[[:space:]]*$/ {
      close(output_file)
      in_mojo = 0
      next
    }

    in_mojo {
      print > output_file
    }

    END {
      if (in_mojo) {
        print "README.md contains an unterminated mojo code fence" > "/dev/stderr"
        exit 1
      }
      print count
    }
  ' README.md
)"

if [[ "$snippet_count" -eq 0 ]]; then
  echo "README check failed: no fenced mojo code blocks found in README.md" >&2
  exit 1
fi

for snippet in "$snippet_dir"/snippet-*.mojo; do
  name="$(basename "$snippet" .mojo)"
  mojo build -I src "$snippet" -o "$snippet_dir/$name"
done

echo "Compiled $snippet_count README Mojo snippet(s)."

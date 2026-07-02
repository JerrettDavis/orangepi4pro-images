#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"

if [ -z "$target" ]; then
  printf 'Usage: %s /path/to/mounted-target-rootfs\n' "$0" >&2
  exit 2
fi

cat <<EOF
DRY RUN: board support install plan.

Target rootfs: $target

Would install:
  - qdtech-touch-x11 fallback package when Xorg fallback is needed
  - display/touch calibration files
  - validation scripts
  - kernel config and DTS provenance docs under /usr/share/doc

No files were copied.
EOF


#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
DRY RUN: kernel build plan.

Preferred first attempt:
  repo:   https://github.com/orangepi-xunlong/linux-orangepi.git
  branch: orange-pi-6.6-sun60iw2
  commit: 8a9be72c9006a87f786736b3aa4e2dfd971c1429

Fallback:
  repo:   https://github.com/orangepi-xunlong/linux-orangepi.git
  branch: orange-pi-5.15-sun60iw2
  commit: 3de7a14a69f9e1fcbfec914c972a5398f0abd6d9

Apply config fragment:
  ../orangepi4pro-board-support/configs/kernel/orangepi4pro-cyberdeck.fragment

No source was cloned and no kernel was built.
EOF


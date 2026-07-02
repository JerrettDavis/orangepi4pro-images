#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
DRY RUN: boot asset plan.

Primary path:
  stock/vendor U-Boot loads legacy-compatible kernel/initrd/DTB assets from the
  shared OPI_BOOT partition.

Generate only after U-Boot commands are verified:
  - uImage if vendor U-Boot lacks booti
  - uInitrd if vendor U-Boot expects legacy initrd
  - boot.scr from reviewed boot.cmd
  - optional extlinux.conf only if supported
  - optional EFI/GRUB tree under OPI_EFI for experiment only

No boot assets were generated.
EOF


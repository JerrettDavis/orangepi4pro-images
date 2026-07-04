#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
board_repo=${BOARD_REPO:-/home/orangepi/orangepi4pro-board-support}
package=${PACKAGE:-/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-nvme-scriptfirst-validated.fex}
expected_package_sha=d798104ccd705e542842fac409b1e2694c6ca19fcfac75fc30036a4535a7d318
device=${DEVICE:-/dev/mmcblk1}
sd_mount=${SD_MOUNT:-/mnt/opisd-rw}
timeout=80
write=false

usage() {
  cat <<'USAGE'
Stage the reviewed vendor script-first extlinux prompt test.

Usage:
  scripts/stage-reviewed-vendor-prompt-test.sh [--timeout SECONDS] [--yes]

Default mode is dry-run only. It validates the exact reviewed script-first
vendor package and bootloader write geometry, but does not write boot sectors
or boot files.

With --yes and ORANGEPI4PRO_STAGE_REVIEWED_BOOTLOADER_TEST=1, it:
  - installs only the validated vendor NVMe script-first TOC1 package to the
    SD bootloader package slot;
  - stages the stock extlinux prompt path to NVMe /boot, EFI, and SD /boot;
  - leaves recovery-oriented assets mirrored to SD and NVMe.

Expected test behavior after a later reboot:
  - U-Boot runs boot.scr before extlinux.
  - boot.scr immediately hands off to U-Boot sysboot/extlinux prompt.
  - extlinux defaults to NVMe after the configured timeout.

This script never writes boot0, NVMe partitions, SPI/MTD, partition tables, or
root filesystems.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout)
      timeout=${2:-}
      shift
      ;;
    --yes)
      write=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$timeout" in
  ''|*[!0-9]*)
    fail '--timeout must be a positive integer'
    ;;
esac

[ -d "$board_repo" ] || fail "board-support repo not found: $board_repo"
[ -f "$package" ] || fail "reviewed package not found: $package"
[ -b "$device" ] || fail "not a block device: $device"

package_sha=$(sha256sum "$package" | awk '{print $1}')
[ "$package_sha" = "$expected_package_sha" ] \
  || fail "unexpected package hash: $package_sha"

mkdir -p "$sd_mount"
if ! mountpoint -q "$sd_mount"; then
  mount "${device}p1" "$sd_mount"
fi

"$board_repo/scripts/validate-boot-package-visual-path.sh" \
  --package "$package" \
  --profile script-first

"$board_repo/scripts/install-sd-boot-package.sh" \
  --package "$package" \
  --device "$device"

printf 'reviewed_package=%s\n' "$package"
printf 'reviewed_package_sha256=%s\n' "$package_sha"
printf 'device=%s\n' "$device"
printf 'sd_mount=%s\n' "$sd_mount"
printf 'timeout=%s\n' "$timeout"
printf 'write=%s\n' "$write"

if [ "$write" != true ]; then
  printf 'dry_run=true\n'
  printf 'No bootloader or boot-file writes performed. Pass --yes and set ORANGEPI4PRO_STAGE_REVIEWED_BOOTLOADER_TEST=1 to stage.\n'
  exit 0
fi

[ "${ORANGEPI4PRO_STAGE_REVIEWED_BOOTLOADER_TEST:-}" = 1 ] \
  || fail 'refusing write without ORANGEPI4PRO_STAGE_REVIEWED_BOOTLOADER_TEST=1'

ORANGEPI4PRO_ALLOW_BOOTLOADER_WRITE=1 \
  "$board_repo/scripts/install-sd-boot-package.sh" \
    --package "$package" \
    --device "$device" \
    --yes

"$repo_root/scripts/stage-vendor-sysboot-prompt-test.sh" \
  --timeout "$timeout" \
  --sd-boot-dir "$sd_mount/boot"

EXPECTED_EXTLINUX_FIRST=true \
EXPECTED_EXTLINUX_PROMPT=1 \
EXPECTED_EXTLINUX_TIMEOUT="$timeout" \
EXPECTED_BOOTMENU_TIMEOUT="$timeout" \
EXPECTED_SELECTOR_CONSOLE=true \
EXPECTED_SELECTOR_VISUAL_TEST=none \
EXPECTED_SELECTOR_VISUAL_HOLD=3 \
EXPECTED_SELECTOR_LOGO_PREINIT=true \
EXPECTED_SELECTOR_LOGO_HOLD=15 \
  "$repo_root/scripts/validate-boot-menu-assets.sh"

EXPECTED_BOOTMENU_FIRST=false \
EXPECTED_SELECTOR_CONSOLE=true \
EXPECTED_SELECTOR_VISUAL_TEST=none \
EXPECTED_SELECTOR_VISUAL_HOLD=3 \
  "$repo_root/scripts/validate-active-boot-source.sh" "$sd_mount"

sync
printf 'Reviewed vendor prompt test staged. Commit/push and settlement validation are still required before reboot.\n'

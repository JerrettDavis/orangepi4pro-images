#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
board_repo=${BOARD_REPO:-/home/orangepi/orangepi4pro-board-support}
package=${PACKAGE:-/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-early-display-secondpass-opibootselect-current.fex}
expected_package_sha=7b1497e4dec101a8e7eea7b6aad100ee4549bebfc89b6b7601d8337433db5848
device=${DEVICE:-/dev/mmcblk1}
sd_mount=${SD_MOUNT:-/mnt/opisd-check}
timeout=30
write=false

usage() {
  cat <<'USAGE'
Stage the SNPS-diagnostic framebuffer U-Boot selector test.

Usage:
  scripts/stage-opibootselect-snpsdiag-test.sh [--timeout SECONDS] [--yes]

Default mode is dry-run. With --yes and ORANGEPI4PRO_STAGE_OPIBOOTSELECT=1,
it installs the hash-locked SNPS-diagnostic TOC1 package with the framebuffer
opi_bootselect command, mirrors boot assets, and enables bootgui_selector.

The staged script pre-initializes HDMI with the known-working second-pass
sunxi_drm fbtest path before running opi_bootselect. It does not write boot0,
NVMe partitions, SPI/MTD, partition tables, or root filesystems.
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

[ "$timeout" -gt 0 ] || fail '--timeout must be greater than zero'
[ -d "$board_repo" ] || fail "board-support repo not found: $board_repo"
[ -f "$package" ] || fail "package not found: $package"
[ -b "$device" ] || fail "not a block device: $device"

package_sha=$(sha256sum "$package" | awk '{print $1}')
[ "$package_sha" = "$expected_package_sha" ] \
  || fail "unexpected package hash: $package_sha"

"$board_repo/scripts/validate-boot-package-visual-path.sh" \
  --package "$package" \
  --profile script-first

grep -a -q 'opi_bootselect' "$package" \
  || fail 'package lacks opi_bootselect command'
grep -a -q 'BOOTLOADER TEST SCREEN' "$package" \
  || fail 'package lacks high-contrast selector test screen'
grep -a -q 'opi_snps_phy_diag' "$package" \
  || fail 'package lacks SNPS PHY diagnostics'

printf 'package=%s\n' "$package"
printf 'package_sha256=%s\n' "$package_sha"
printf 'device=%s\n' "$device"
printf 'sd_mount=%s\n' "$sd_mount"
printf 'bootgui_selector_timeout=%s\n' "$timeout"
printf 'write=%s\n' "$write"

if [ "$write" != true ]; then
  printf 'dry_run=true\n'
  printf 'No bootloader or boot-file writes performed. Pass --yes and set ORANGEPI4PRO_STAGE_OPIBOOTSELECT=1 to stage.\n'
  exit 0
fi

[ "${ORANGEPI4PRO_STAGE_OPIBOOTSELECT:-}" = 1 ] \
  || fail 'refusing write without ORANGEPI4PRO_STAGE_OPIBOOTSELECT=1'

mkdir -p "$sd_mount"
if ! mountpoint -q "$sd_mount"; then
  mount "${device}p1" "$sd_mount"
fi

ORANGEPI4PRO_ALLOW_BOOTLOADER_WRITE=1 \
  "$board_repo/scripts/install-sd-boot-package.sh" \
    --package "$package" \
    --device "$device" \
    --yes

"$repo_root/scripts/install-extlinux-selector.sh" /boot /boot/efi "$sd_mount/boot"

patch_env() {
  local env_file=$1
  [ -e "$env_file" ] || return 0
  sed -i \
    -e 's/^grub_first=.*/grub_first=false/' \
    -e 's/^extlinux_first=.*/extlinux_first=false/' \
    -e 's/^direct_booti_first=.*/direct_booti_first=false/' \
    -e 's/^bootmenu_first=.*/bootmenu_first=false/' \
    -e 's/^bootmenu_timeout=.*/bootmenu_timeout=30/' \
    -e 's/^bootmenu_default=.*/bootmenu_default=nvme/' \
    -e 's/^bootmenu_video_preinit=.*/bootmenu_video_preinit=false/' \
    -e 's/^kernel_selector_first=.*/kernel_selector_first=false/' \
    -e 's/^kernel_selector_timeout=.*/kernel_selector_timeout=30/' \
    -e 's/^selector_console=.*/selector_console=false/' \
    -e 's/^selector_prompt=.*/selector_prompt=true/' \
    -e 's/^selector_bitmap=.*/selector_bitmap=false/' \
    -e 's/^selector_visual_test=.*/selector_visual_test=none/' \
    -e 's/^selector_visual_hold=.*/selector_visual_hold=3/' \
    -e 's/^selector_logo_preinit=.*/selector_logo_preinit=false/' \
    -e 's/^selector_logo_hold=.*/selector_logo_hold=15/' \
    -e 's/^selector_diag_force_bootm=.*/selector_diag_force_bootm=false/' \
    -e 's/^bootgui_selector=.*/bootgui_selector=true/' \
    -e "s/^bootgui_selector_timeout=.*/bootgui_selector_timeout=${timeout}/" \
    "$env_file"
}

patch_env /boot/orangepiEnv.txt
patch_env /boot/efi/orangepiEnv.txt
patch_env "$sd_mount/boot/orangepiEnv.txt"

EXPECTED_EXTLINUX_FIRST=false \
EXPECTED_BOOTMENU_FIRST=false \
EXPECTED_BOOTMENU_TIMEOUT=30 \
EXPECTED_BOOTMENU_DEFAULT=nvme \
EXPECTED_BOOTMENU_VIDEO_PREINIT=false \
EXPECTED_KERNEL_SELECTOR_FIRST=false \
EXPECTED_KERNEL_SELECTOR_TIMEOUT=30 \
EXPECTED_SELECTOR_CONSOLE=false \
EXPECTED_SELECTOR_VISUAL_TEST=none \
EXPECTED_SELECTOR_VISUAL_HOLD=3 \
EXPECTED_SELECTOR_LOGO_PREINIT=false \
EXPECTED_BOOTGUI_SELECTOR=true \
EXPECTED_BOOTGUI_SELECTOR_TIMEOUT="$timeout" \
  "$repo_root/scripts/validate-boot-menu-assets.sh"

EXPECTED_BOOTMENU_FIRST=false \
EXPECTED_SELECTOR_CONSOLE=false \
EXPECTED_SELECTOR_VISUAL_TEST=none \
EXPECTED_SELECTOR_VISUAL_HOLD=3 \
  "$repo_root/scripts/validate-active-boot-source.sh" "$sd_mount"

sync
printf 'SNPS-diagnostic framebuffer U-Boot selector test staged. Commit/push and settlement validation are still required before reboot.\n'

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
board_repo=${BOARD_REPO:-/home/orangepi/orangepi4pro-board-support}
package=${PACKAGE:-/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-early-display-secondpass-snpsdiag-current.fex}
expected_package_sha=6316342d678674318b1ed1e30c5d0503ef5b30b2ebc23c0db564e332b40634b6
device=${DEVICE:-/dev/mmcblk1}
sd_mount=${SD_MOUNT:-/mnt/opisd-check}
hold=20
write=false

usage() {
  cat <<'USAGE'
Stage the bounded U-Boot HDMI local-disable framebuffer visual test.

Usage:
  scripts/stage-localdisable-fbtest-visual-test.sh [--hold SECONDS] [--yes]

Default mode is dry-run. With --yes and
ORANGEPI4PRO_STAGE_LOCALDISABLE_FBTEST=1, it:
  - installs only the hash-locked local-disable/SNPS-diagnostic second-pass
    TOC1 package to the SD bootloader package slot;
  - stages repo boot assets to NVMe /boot, EFI, and SD /boot;
  - enables selector_visual_test=fbtest with a visible hold;
  - disables bootmenu/kernel selector for this diagnostic boot only.

It does not write boot0, NVMe partitions, SPI/MTD, partition tables, or root
filesystems.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hold)
      hold=${2:-}
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

case "$hold" in
  ''|*[!0-9]*)
    fail '--hold must be a positive integer'
    ;;
esac

[ -d "$board_repo" ] || fail "board-support repo not found: $board_repo"
[ -f "$package" ] || fail "package not found: $package"
[ -b "$device" ] || fail "not a block device: $device"

package_sha=$(sha256sum "$package" | awk '{print $1}')
[ "$package_sha" = "$expected_package_sha" ] \
  || fail "unexpected package hash: $package_sha"

"$board_repo/scripts/validate-boot-package-visual-path.sh" \
  --package "$package" \
  --profile script-first

printf 'package=%s\n' "$package"
printf 'package_sha256=%s\n' "$package_sha"
printf 'device=%s\n' "$device"
printf 'sd_mount=%s\n' "$sd_mount"
printf 'selector_visual_test=fbtest\n'
printf 'selector_visual_hold=%s\n' "$hold"
printf 'write=%s\n' "$write"

if [ "$write" != true ]; then
  printf 'dry_run=true\n'
  printf 'No bootloader or boot-file writes performed. Pass --yes and set ORANGEPI4PRO_STAGE_LOCALDISABLE_FBTEST=1 to stage.\n'
  exit 0
fi

[ "${ORANGEPI4PRO_STAGE_LOCALDISABLE_FBTEST:-}" = 1 ] \
  || fail 'refusing write without ORANGEPI4PRO_STAGE_LOCALDISABLE_FBTEST=1'

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
    -e 's/^kernel_selector_first=.*/kernel_selector_first=false/' \
    -e 's/^kernel_selector_timeout=.*/kernel_selector_timeout=30/' \
    -e 's/^selector_console=.*/selector_console=false/' \
    -e 's/^selector_prompt=.*/selector_prompt=true/' \
    -e 's/^selector_bitmap=.*/selector_bitmap=false/' \
    -e 's/^selector_visual_test=.*/selector_visual_test=fbtest/' \
    -e "s/^selector_visual_hold=.*/selector_visual_hold=${hold}/" \
    -e 's/^selector_logo_preinit=.*/selector_logo_preinit=false/' \
    -e 's/^selector_logo_hold=.*/selector_logo_hold=15/' \
    -e 's/^selector_diag_force_bootm=.*/selector_diag_force_bootm=false/' \
    -e 's/^bootgui_selector=.*/bootgui_selector=false/' \
    -e 's/^bootgui_selector_timeout=.*/bootgui_selector_timeout=10/' \
    "$env_file"
}

patch_env /boot/orangepiEnv.txt
patch_env /boot/efi/orangepiEnv.txt
patch_env "$sd_mount/boot/orangepiEnv.txt"

EXPECTED_EXTLINUX_FIRST=false \
EXPECTED_BOOTMENU_FIRST=false \
EXPECTED_BOOTMENU_TIMEOUT=30 \
EXPECTED_BOOTMENU_DEFAULT=nvme \
EXPECTED_KERNEL_SELECTOR_FIRST=false \
EXPECTED_KERNEL_SELECTOR_TIMEOUT=30 \
EXPECTED_SELECTOR_CONSOLE=false \
EXPECTED_SELECTOR_VISUAL_TEST=fbtest \
EXPECTED_SELECTOR_VISUAL_HOLD="$hold" \
EXPECTED_SELECTOR_LOGO_PREINIT=false \
  "$repo_root/scripts/validate-boot-menu-assets.sh"

EXPECTED_BOOTMENU_FIRST=false \
EXPECTED_SELECTOR_CONSOLE=false \
EXPECTED_SELECTOR_VISUAL_TEST=fbtest \
EXPECTED_SELECTOR_VISUAL_HOLD="$hold" \
  "$repo_root/scripts/validate-active-boot-source.sh" "$sd_mount"

sync
printf 'Local-disable fbtest visual diagnostic staged. Commit/push and settlement validation are still required before reboot.\n'

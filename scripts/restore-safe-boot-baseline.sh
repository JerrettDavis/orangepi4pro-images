#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
board_repo=${BOARD_REPO:-/home/orangepi/orangepi4pro-board-support}
package=${SAFE_BOOT_PACKAGE:-/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package_a733_nvme.fex}
device=${SAFE_BOOT_DEVICE:-/dev/mmcblk1}
sd_mount=${SAFE_SD_MOUNT:-/mnt/opisd-rw}
boot_dir=${SAFE_BOOT_DIR:-/boot}
efi_dir=${SAFE_EFI_DIR:-/boot/efi}
write=false

usage() {
  cat <<'USAGE'
Restore or verify the known safe Orange Pi 4 Pro boot baseline.

Usage:
  scripts/restore-safe-boot-baseline.sh [--yes]

Default mode is a dry run. It verifies the vendor NVMe boot package write
geometry and shows the current boot asset state without writing boot sectors.

With --yes and ORANGEPI4PRO_ALLOW_BOOTLOADER_WRITE=1, it:
  - writes only the vendor NVMe TOC1 package to the SD bootloader package slot;
  - stages repo boot assets to NVMe /boot, EFI, and SD /boot;
  - leaves the staged env at extlinux_first=true and selector_visual_test=none.

It never writes NVMe partitions, SPI/MTD, boot0, partition tables, or rootfs
contents.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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

[ -f "$package" ] || {
  printf 'ERROR: safe package not found: %s\n' "$package" >&2
  exit 1
}
[ -d "$board_repo" ] || {
  printf 'ERROR: board-support repo not found: %s\n' "$board_repo" >&2
  exit 1
}

mkdir -p "$sd_mount"
if ! mountpoint -q "$sd_mount"; then
  mount "$device"p1 "$sd_mount"
fi

printf 'safe_package=%s\n' "$package"
sha256sum "$package"
printf 'device=%s\n' "$device"
printf 'sd_mount=%s\n' "$sd_mount"
printf 'write=%s\n' "$write"

if [ "$write" = true ]; then
  ORANGEPI4PRO_ALLOW_BOOTLOADER_WRITE=${ORANGEPI4PRO_ALLOW_BOOTLOADER_WRITE:-} \
    "$board_repo/scripts/install-sd-boot-package.sh" \
      --package "$package" \
      --device "$device" \
      --yes
  "$repo_root/scripts/install-extlinux-selector.sh" "$boot_dir" "$efi_dir" "$sd_mount/boot"
else
  "$board_repo/scripts/install-sd-boot-package.sh" \
    --package "$package" \
    --device "$device"
fi

EXPECTED_EXTLINUX_FIRST=true \
EXPECTED_SELECTOR_VISUAL_TEST=none \
EXPECTED_SELECTOR_VISUAL_HOLD=3 \
EXPECTED_SELECTOR_LOGO_PREINIT=true \
EXPECTED_SELECTOR_LOGO_HOLD=15 \
  "$repo_root/scripts/validate-boot-menu-assets.sh"

EXPECTED_BOOTMENU_FIRST=false \
EXPECTED_SELECTOR_VISUAL_TEST=none \
EXPECTED_SELECTOR_VISUAL_HOLD=3 \
  "$repo_root/scripts/validate-active-boot-source.sh" "$sd_mount"

sync
printf 'Safe boot baseline %s completed.\n' "$([ "$write" = true ] && printf restore || printf dry-run)"

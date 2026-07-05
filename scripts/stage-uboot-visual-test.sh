#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_dir=/boot
efi_dir=/boot/efi
sd_boot_dir=
test_name=colorbar
hold=8

usage() {
  cat <<'USAGE'
Stage a bounded U-Boot visual diagnostic.

Usage:
  scripts/stage-uboot-visual-test.sh [--test colorbar|fbtest|fbcycle|hdmi20_pattern|none] [--hold SECONDS] [--sd-boot-dir DIR]

The colorbar test runs U-Boot's built-in `sunxi_drm colorbar 1`, waits for the
configured hold time, marks the kernel command line with either
`bootchooser=uboot-visual-colorbar-ok` or `bootchooser=uboot-visual-colorbar-fail`,
then boots NVMe via the known legacy bootm path.

The fbtest test runs the board-support `sunxi_drm fbtest` command, which paints
directly into the active U-Boot DRM framebuffer.

The fbcycle test runs the board-support `sunxi_drm fbcycle` command, which
cycles the HDMI display pipeline once and then paints a high-contrast framebuffer.

The hdmi20_pattern test runs the vendor `sunxi_hdmi20 pattern 1` command. That
uses the HDMI controller's internal pattern generator and helps isolate link
bring-up from DE/TCON/framebuffer rendering.

This writes boot files only. It does not write bootloader sectors, NVMe
partition tables, SPI, or MTD.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --test)
      test_name=${2:-}
      shift
      ;;
    --hold)
      hold=${2:-}
      shift
      ;;
    --boot-dir)
      boot_dir=${2:-}
      shift
      ;;
    --efi-dir)
      efi_dir=${2:-}
      shift
      ;;
    --sd-boot-dir)
      sd_boot_dir=${2:-}
      shift
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

case "$test_name" in
  colorbar|fbtest|fbcycle|hdmi20_pattern|none) ;;
  *)
    printf 'ERROR: --test must be colorbar, fbtest, fbcycle, hdmi20_pattern, or none\n' >&2
    exit 2
    ;;
esac

case "$hold" in
  ''|*[!0-9]*)
    printf 'ERROR: --hold must be a positive integer\n' >&2
    exit 2
    ;;
esac

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'ERROR: rerun with sudo so boot assets can be written\n' >&2
  exit 1
fi

"$repo_root/scripts/install-extlinux-selector.sh" "$boot_dir" "$efi_dir" "$sd_boot_dir"

patch_env() {
  local env_file=$1
  [ -e "$env_file" ] || return 0
  sed -i \
    -e "s/^grub_first=.*/grub_first=false/" \
    -e "s/^extlinux_first=.*/extlinux_first=false/" \
    -e "s/^direct_booti_first=.*/direct_booti_first=false/" \
    -e "s/^bootmenu_first=.*/bootmenu_first=false/" \
    -e "s/^bootmenu_default=.*/bootmenu_default=nvme/" \
    -e "s/^selector_console=.*/selector_console=false/" \
    -e "s/^selector_prompt=.*/selector_prompt=true/" \
    -e "s/^selector_bitmap=.*/selector_bitmap=false/" \
    -e "s/^selector_visual_test=.*/selector_visual_test=${test_name}/" \
    -e "s/^selector_visual_hold=.*/selector_visual_hold=${hold}/" \
    -e "s/^selector_logo_preinit=.*/selector_logo_preinit=false/" \
    -e "s/^selector_logo_hold=.*/selector_logo_hold=3/" \
    -e "s/^selector_diag_force_bootm=.*/selector_diag_force_bootm=false/" \
    -e "s/^bootgui_selector=.*/bootgui_selector=false/" \
    -e "s/^bootgui_selector_timeout=.*/bootgui_selector_timeout=10/" \
    "$env_file"
}

patch_env "$boot_dir/orangepiEnv.txt"
patch_env "$efi_dir/orangepiEnv.txt"
if [ -n "$sd_boot_dir" ]; then
  patch_env "$sd_boot_dir/orangepiEnv.txt"
fi

sync
printf 'Staged U-Boot visual test: test=%s hold=%s\n' "$test_name" "$hold"

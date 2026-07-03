#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_dir=/boot
efi_dir=/boot/efi
sd_boot_dir=
timeout=200
default_entry=ubuntu-nvme

usage() {
  cat <<'USAGE'
Stage the extlinux prompt selector on the live boot filesystems.

Usage:
  scripts/stage-extlinux-prompt-selector.sh [--timeout TENTHS] [--default ubuntu-nvme|ubuntu-sd] [--sd-boot-dir DIR]

This stages the repo's boot.cmd/extlinux assets and configures U-Boot to enter
the prompted extlinux path before legacy bootm. It writes boot filesystem files
only. It does not write bootloader sectors, NVMe partitions, SPI, MTD, or TOC1.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout)
      timeout=${2:-}
      shift
      ;;
    --default)
      default_entry=${2:-}
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

case "$timeout" in
  ''|*[!0-9]*)
    printf 'ERROR: --timeout must be a non-negative integer in tenths of seconds\n' >&2
    exit 2
    ;;
esac

case "$default_entry" in
  ubuntu-nvme|ubuntu-sd) ;;
  *)
    printf 'ERROR: --default must be ubuntu-nvme or ubuntu-sd\n' >&2
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
    -e "s/^extlinux_first=.*/extlinux_first=true/" \
    -e "s/^direct_booti_first=.*/direct_booti_first=false/" \
    -e "s/^bootmenu_first=.*/bootmenu_first=false/" \
    -e "s/^bootmenu_default=.*/bootmenu_default=nvme/" \
    -e "s/^selector_console=.*/selector_console=false/" \
    -e "s/^selector_prompt=.*/selector_prompt=true/" \
    -e "s/^selector_bitmap=.*/selector_bitmap=false/" \
    -e "s/^selector_visual_test=.*/selector_visual_test=none/" \
    -e "s/^selector_visual_hold=.*/selector_visual_hold=8/" \
    -e "s/^selector_logo_preinit=.*/selector_logo_preinit=false/" \
    -e "s/^selector_logo_hold=.*/selector_logo_hold=3/" \
    -e "s/^selector_diag_force_bootm=.*/selector_diag_force_bootm=false/" \
    -e "s/^bootgui_selector=.*/bootgui_selector=false/" \
    -e "s/^bootgui_selector_timeout=.*/bootgui_selector_timeout=10/" \
    "$env_file"
}

patch_extlinux() {
  local extlinux_file=$1
  [ -e "$extlinux_file" ] || return 0
  sed -i \
    -e "s/^DEFAULT .*/DEFAULT ${default_entry}/" \
    -e "s/^PROMPT .*/PROMPT 1/" \
    -e "s/^TIMEOUT .*/TIMEOUT ${timeout}/" \
    "$extlinux_file"
}

patch_env "$boot_dir/orangepiEnv.txt"
patch_env "$efi_dir/orangepiEnv.txt"
patch_extlinux "$boot_dir/extlinux/extlinux.conf"
patch_extlinux "$efi_dir/extlinux/extlinux.conf"

if [ -n "$sd_boot_dir" ]; then
  patch_env "$sd_boot_dir/orangepiEnv.txt"
  patch_extlinux "$sd_boot_dir/extlinux/extlinux.conf"
fi

sync
printf 'Staged extlinux prompt selector: default=%s timeout=%s tenths\n' "$default_entry" "$timeout"

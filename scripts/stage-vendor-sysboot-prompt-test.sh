#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_dir=/boot
efi_dir=/boot/efi
sd_boot_dir=
timeout=20

usage() {
  cat <<'USAGE'
Stage a vendor-U-Boot sysboot prompt test.

Usage:
  scripts/stage-vendor-sysboot-prompt-test.sh [--sd-boot-dir DIR] [--timeout SECONDS]

This stages boot files only. It disables the custom opi_bootselect path and
enables U-Boot's extlinux prompt path:

  bootgui_selector=false
  extlinux_first=true
  selector_prompt=true
  selector_console=true

Pair this with the vendor NVMe script-first boot package prepared by
orangepi4pro-board-support/scripts/prepare-vendor-nvme-scriptfirst-package.sh.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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
    --timeout)
      timeout=${2:-}
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
    printf 'ERROR: --timeout must be a positive integer\n' >&2
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
    -e 's/^bootgui_selector=.*/bootgui_selector=false/' \
    -e 's/^bootmenu_first=.*/bootmenu_first=false/' \
    -e "s/^bootmenu_timeout=.*/bootmenu_timeout=${timeout}/" \
    -e 's/^extlinux_first=.*/extlinux_first=true/' \
    -e 's/^selector_prompt=.*/selector_prompt=true/' \
    -e 's/^selector_console=.*/selector_console=true/' \
    -e 's/^selector_visual_test=.*/selector_visual_test=none/' \
    "$env_file"
}

patch_env "$boot_dir/orangepiEnv.txt"
patch_env "$efi_dir/orangepiEnv.txt"
if [ -n "$sd_boot_dir" ]; then
  patch_env "$sd_boot_dir/orangepiEnv.txt"
fi

sync
printf 'Staged vendor sysboot prompt test: timeout=%s\n' "$timeout"

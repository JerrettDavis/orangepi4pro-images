#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target=sd
boot_dir=/boot
efi_dir=/boot/efi
sd_boot_dir=
timeout=20

usage() {
  cat <<'USAGE'
Stage a deterministic U-Boot bootmenu default-entry test.

Usage:
  scripts/stage-bootmenu-default-test.sh [--target sd|nvme] [--sd-boot-dir DIR] [--timeout SECONDS]

The script installs the repo boot assets, then sets bootmenu_default in
orangepiEnv.txt across the requested boot directories. It writes boot files
only; it does not write bootloader sectors, NVMe partition tables, SPI, or MTD.

After reboot:
  scripts/assert-bootchooser.sh uboot-bootmenu-sd
  scripts/assert-bootchooser.sh uboot-bootmenu-nvme
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      target=${2:-}
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

case "$target" in
  sd|nvme) ;;
  *)
    printf 'ERROR: --target must be sd or nvme\n' >&2
    exit 2
    ;;
esac

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
    -e "s/^bootmenu_default=.*/bootmenu_default=${target}/" \
    -e "s/^bootmenu_timeout=.*/bootmenu_timeout=${timeout}/" \
    "$env_file"
}

patch_env "$boot_dir/orangepiEnv.txt"
patch_env "$efi_dir/orangepiEnv.txt"
if [ -n "$sd_boot_dir" ]; then
  patch_env "$sd_boot_dir/orangepiEnv.txt"
fi

sync
printf 'Staged bootmenu default test: target=%s timeout=%s\n' "$target" "$timeout"

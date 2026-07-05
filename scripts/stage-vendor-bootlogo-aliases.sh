#!/usr/bin/env bash
set -euo pipefail

boot_dir=/boot
efi_dir=/boot/efi
sd_boot_dir=
source_logo=

usage() {
  cat <<'USAGE'
Stage vendor U-Boot logo filename aliases without changing the boot path.

Usage:
  scripts/stage-vendor-bootlogo-aliases.sh [--source-logo FILE] [--boot-dir DIR] [--efi-dir DIR] [--sd-boot-dir DIR]

The A733 vendor U-Boot logo path hard-codes bootlogo.bmp, while adjacent
factory/fast-logo paths also reference boot.bmp and boot1.bmp. This script
copies the factory-style logo asset to all three names on mounted boot
filesystems only. It does not edit boot scripts, install bootloader packages,
write raw devices, or touch NVMe/SD partition tables.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-logo)
      source_logo=${2:-}
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

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'ERROR: rerun with sudo so mounted boot assets can be written\n' >&2
  exit 1
fi

if [ -z "$source_logo" ]; then
  if [ -r "$boot_dir/logo.bmp" ]; then
    source_logo=$boot_dir/logo.bmp
  elif [ -r "$efi_dir/logo.bmp" ]; then
    source_logo=$efi_dir/logo.bmp
  elif [ -n "$sd_boot_dir" ] && [ -r "$sd_boot_dir/logo.bmp" ]; then
    source_logo=$sd_boot_dir/logo.bmp
  else
    printf 'ERROR: pass --source-logo or restore a readable logo.bmp first\n' >&2
    exit 1
  fi
fi

if [ ! -r "$source_logo" ]; then
  printf 'ERROR: source logo is not readable: %s\n' "$source_logo" >&2
  exit 1
fi

install_aliases() {
  local target=$1
  [ -n "$target" ] || return 0
  [ -d "$target" ] || return 0
  install -m 0644 "$source_logo" "$target/bootlogo.bmp"
  install -m 0644 "$source_logo" "$target/boot.bmp"
  install -m 0644 "$source_logo" "$target/boot1.bmp"
  install -m 0644 "$source_logo" "$target/fastbootlogo.bmp"
}

install_aliases "$boot_dir"
install_aliases "$efi_dir"
install_aliases "$sd_boot_dir"

sync
printf 'Staged vendor boot logo aliases from %s\n' "$source_logo"

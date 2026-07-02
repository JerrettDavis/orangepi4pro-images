#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_dir=${1:-/boot}
efi_dir=${2:-/boot/efi}
sd_boot_dir=${3:-}
stamp=$(date -u +%Y%m%dT%H%M%SZ)

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'ERROR: rerun with sudo so boot assets can be written\n' >&2
  exit 1
fi

require_file() {
  [ -e "$1" ] || {
    printf 'ERROR: missing %s\n' "$1" >&2
    exit 1
  }
}

install_to_boot_dir() {
  local target=$1
  require_file "$target/uImage-5.15.147-sun60iw2-cyberdeck"
  require_file "$target/uInitrd-5.15.147-sun60iw2-cyberdeck"
  require_file "$target/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb"

  mkdir -p "$target/backups/pre-extlinux-selector-$stamp" "$target/extlinux"
  for file in boot.cmd boot.scr orangepiEnv.txt extlinux/extlinux.conf; do
    [ -e "$target/$file" ] && cp -a "$target/$file" "$target/backups/pre-extlinux-selector-$stamp/${file//\//-}"
  done

  install -m 0644 "$repo_root/configs/boot.cmd" "$target/boot.cmd"
  install -m 0644 "$repo_root/configs/orangepiEnv.txt" "$target/orangepiEnv.txt"
  install -m 0644 "$repo_root/configs/extlinux.conf" "$target/extlinux/extlinux.conf"
  mkimage -C none -A arm -T script -d "$target/boot.cmd" "$target/boot.scr"
}

install_to_boot_dir "$boot_dir"

if [ -d "$efi_dir" ]; then
  mkdir -p "$efi_dir/extlinux"
  cp -a "$boot_dir/boot.cmd" "$efi_dir/boot.cmd"
  cp -a "$boot_dir/boot.scr" "$efi_dir/boot.scr"
  cp -a "$boot_dir/orangepiEnv.txt" "$efi_dir/orangepiEnv.txt"
  cp -a "$boot_dir/extlinux/extlinux.conf" "$efi_dir/extlinux/extlinux.conf"
fi

if [ -n "$sd_boot_dir" ]; then
  install_to_boot_dir "$sd_boot_dir"
fi

sync
printf 'Installed extlinux selector assets from %s\n' "$repo_root"

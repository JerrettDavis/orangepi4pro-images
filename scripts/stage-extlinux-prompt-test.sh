#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_dir=${BOOT_DIR:-/boot}
efi_dir=${EFI_DIR:-/boot/efi}
sd_boot_dir=${SD_BOOT_DIR:-/mnt/opisd-ro/boot}
prompt=${PROMPT_VALUE:-1}
timeout=${TIMEOUT_VALUE:-100}
default_label=${DEFAULT_LABEL:-ubuntu-nvme}
stamp=$(date -u +%Y%m%dT%H%M%SZ)

usage() {
  cat <<'USAGE'
Stage a bounded extlinux prompt test on the live Orange Pi boot files.

Defaults:
  PROMPT_VALUE=1
  TIMEOUT_VALUE=100
  DEFAULT_LABEL=ubuntu-nvme
  The staged env also sets bootlogo=false, logo=disabled,
  selector_console=true, and selector_prompt=true.
  BOOT_DIR=/boot
  EFI_DIR=/boot/efi
  SD_BOOT_DIR=/mnt/opisd-ro/boot

The script backs up boot.cmd, boot.scr, orangepiEnv.txt, and extlinux.conf
under each target boot directory, then installs the repo boot templates with:

  PROMPT 1
  TIMEOUT 100
  DEFAULT ubuntu-nvme
  selector_console=true

No boot sectors, SPI flash, partition tables, or root filesystems are written.
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

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

validate_label() {
  grep -Eq "^LABEL[[:space:]]+$default_label$" "$repo_root/configs/extlinux.conf" || {
    printf 'ERROR: DEFAULT_LABEL is not present in configs/extlinux.conf: %s\n' "$default_label" >&2
    exit 1
  }
}

prepare_tree() {
  local target=$1

  require_file "$target/uImage-5.15.147-sun60iw2-cyberdeck"
  require_file "$target/uInitrd-5.15.147-sun60iw2-cyberdeck"
  require_file "$target/uImage-5.15.147-sun60iw2"
  require_file "$target/uInitrd-5.15.147-sun60iw2"
  require_file "$target/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb"
  require_file "$target/dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb"

  mkdir -p "$target/backups/extlinux-prompt-test-$stamp" "$target/extlinux"
  for file in boot.cmd boot.scr orangepiEnv.txt extlinux/extlinux.conf; do
    [ -e "$target/$file" ] && cp -a "$target/$file" "$target/backups/extlinux-prompt-test-$stamp/${file//\//-}"
  done

  install -m 0644 "$repo_root/configs/boot.cmd" "$target/boot.cmd"
  install -m 0644 "$repo_root/configs/orangepiEnv.txt" "$target/orangepiEnv.txt"
  install -m 0644 "$repo_root/configs/extlinux.conf" "$target/extlinux/extlinux.conf"

  sed -i \
    -e "s/^PROMPT .*/PROMPT $prompt/" \
    -e "s/^TIMEOUT .*/TIMEOUT $timeout/" \
    -e "s/^DEFAULT .*/DEFAULT $default_label/" \
    "$target/extlinux/extlinux.conf"
  sed -i \
    -e 's/^bootlogo=.*/bootlogo=false/' \
    -e 's/^selector_console=.*/selector_console=true/' \
    -e 's/^selector_prompt=.*/selector_prompt=true/' \
    -e 's/^logo=.*/logo=disabled/' \
    "$target/orangepiEnv.txt"

  mkimage -C none -A arm -T script -d "$target/boot.cmd" "$target/boot.scr" >/dev/null
}

validate_label

printf 'Staging extlinux prompt test: PROMPT=%s TIMEOUT=%s DEFAULT=%s\n' \
  "$prompt" "$timeout" "$default_label"

prepare_tree "$boot_dir"

if [ -d "$efi_dir" ]; then
  mkdir -p "$efi_dir/extlinux"
  cp -a "$boot_dir/boot.cmd" "$efi_dir/boot.cmd"
  cp -a "$boot_dir/boot.scr" "$efi_dir/boot.scr"
  cp -a "$boot_dir/orangepiEnv.txt" "$efi_dir/orangepiEnv.txt"
  cp -a "$boot_dir/extlinux/extlinux.conf" "$efi_dir/extlinux/extlinux.conf"
fi

if [ -d "$sd_boot_dir" ]; then
  sd_mount=${sd_boot_dir%/boot}
  remounted_ro=false
  if mountpoint -q "$sd_mount" && ! [ -w "$sd_boot_dir" ]; then
    mount -o remount,rw "$sd_mount"
    remounted_ro=true
  fi
  prepare_tree "$sd_boot_dir"
  if [ "$remounted_ro" = true ]; then
    mount -o remount,ro "$sd_mount"
  fi
fi

sync

printf 'Backups are under */backups/extlinux-prompt-test-%s\n' "$stamp"
printf 'Prompt test staged. Reboot should default to %s after the timeout.\n' "$default_label"

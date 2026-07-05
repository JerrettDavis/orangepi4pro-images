#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_dir=/boot
efi_dir=/boot/efi
sd_boot_dir=
hold=20
source_logo=

usage() {
  cat <<'USAGE'
Stage a factory-logo U-Boot preinit diagnostic.

Usage:
  scripts/stage-factory-logo-preinit-test.sh [--hold SECONDS] [--source-logo FILE] [--sd-boot-dir DIR]

This restores the Orange Pi logo asset to the filenames the A733 U-Boot logo
loader searches: /boot/bootlogo.bmp, /boot/boot1.bmp, /boot/boot.bmp, and
/boot/fastbootlogo.bmp. It then stages boot.cmd to run `sunxi_show_logo`, hold,
and boot NVMe through the known legacy bootm path so the result is visible and
recorded in /proc/cmdline.

This writes boot filesystem files only. It does not write bootloader sectors,
NVMe partitions, SPI, MTD, or TOC1.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hold)
      hold=${2:-}
      shift
      ;;
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

case "$hold" in
  ''|*[!0-9]*)
    printf 'ERROR: --hold must be a non-negative integer\n' >&2
    exit 2
    ;;
esac

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'ERROR: rerun with sudo so boot assets can be written\n' >&2
  exit 1
fi

if [ -z "$source_logo" ]; then
  if [ -r "$boot_dir/logo.bmp" ]; then
    source_logo=$boot_dir/logo.bmp
  elif [ -r "$efi_dir/logo.bmp" ]; then
    source_logo=$efi_dir/logo.bmp
  else
    printf 'ERROR: pass --source-logo or restore /boot/logo.bmp first\n' >&2
    exit 1
  fi
fi

if [ ! -r "$source_logo" ]; then
  printf 'ERROR: source logo is not readable: %s\n' "$source_logo" >&2
  exit 1
fi

install_logo() {
  local target=$1
  [ -d "$target" ] || return 0
  install -m 0644 "$source_logo" "$target/bootlogo.bmp"
  install -m 0644 "$source_logo" "$target/boot.bmp"
  install -m 0644 "$source_logo" "$target/boot1.bmp"
  install -m 0644 "$source_logo" "$target/fastbootlogo.bmp"
}

stage_args=(
  --timeout 200
  --default ubuntu-nvme
  --video-console false
  --logo-preinit true
  --logo-hold "$hold"
  --extlinux-first false
  --diag-force-bootm true
  --boot-dir "$boot_dir"
  --efi-dir "$efi_dir"
)
if [ -n "$sd_boot_dir" ]; then
  stage_args+=(--sd-boot-dir "$sd_boot_dir")
fi

"$repo_root/scripts/stage-extlinux-prompt-selector.sh" "${stage_args[@]}"

install_logo "$boot_dir"
install_logo "$efi_dir"
if [ -n "$sd_boot_dir" ]; then
  install_logo "$sd_boot_dir"
fi

sync
printf 'Staged factory-logo preinit test: hold=%s source=%s\n' "$hold" "$source_logo"

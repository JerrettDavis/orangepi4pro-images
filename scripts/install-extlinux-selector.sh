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

generate_selector_bitmap() {
  local out=$1

  python3 - "$out" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
img = Image.new("RGB", (320, 240), (5, 7, 10))
draw = ImageDraw.Draw(img)

try:
    title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    body_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    small_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
except OSError:
    title_font = body_font = small_font = None

draw.rectangle((0, 0, 319, 239), fill=(5, 7, 10))
draw.rectangle((0, 0, 319, 7), fill=(238, 137, 28))
draw.text((18, 22), "Orange Pi 4 Pro", fill=(255, 185, 72), font=title_font)
draw.text((18, 50), "Boot Selector", fill=(238, 244, 248), font=body_font)
draw.line((18, 78, 302, 78), fill=(78, 86, 96), width=1)
draw.text((24, 96), "Use USB keyboard arrows + Enter", fill=(240, 244, 248), font=small_font)
draw.text((24, 122), "Ubuntu NVMe - cyberdeck kernel", fill=(240, 244, 248), font=body_font)
draw.text((24, 148), "Ubuntu SD - stock kernel", fill=(240, 244, 248), font=body_font)
draw.text((24, 174), "Ubuntu NVMe - verbose boot", fill=(240, 244, 248), font=body_font)
draw.text((18, 210), "Default: NVMe after 10 seconds", fill=(168, 178, 190), font=small_font)
img.save(out, "BMP")
PY
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
  generate_selector_bitmap "$target/boot.bmp"
  mkimage -C none -A arm -T script -d "$target/boot.cmd" "$target/boot.scr"
}

with_writable_mount() {
  local target=$1
  local mount_dir
  local remounted=false

  mount_dir=$(findmnt -n -o TARGET --target "$target" || true)
  if [ -z "$mount_dir" ]; then
    install_to_boot_dir "$target"
    return
  fi

  if findmnt -n -o OPTIONS --target "$target" | grep -qw ro; then
    mount -o remount,rw "$mount_dir"
    remounted=true
  fi

  install_to_boot_dir "$target"

  if [ "$remounted" = true ]; then
    sync
    mount -o remount,ro "$mount_dir"
  fi
}

install_to_boot_dir "$boot_dir"

if [ -d "$efi_dir" ]; then
  mkdir -p "$efi_dir/extlinux"
  cp -a "$boot_dir/boot.cmd" "$efi_dir/boot.cmd"
  cp -a "$boot_dir/boot.scr" "$efi_dir/boot.scr"
  cp -a "$boot_dir/orangepiEnv.txt" "$efi_dir/orangepiEnv.txt"
  cp -a "$boot_dir/extlinux/extlinux.conf" "$efi_dir/extlinux/extlinux.conf"
  cp -a "$boot_dir/boot.bmp" "$efi_dir/boot.bmp"
fi

if [ -n "$sd_boot_dir" ]; then
  with_writable_mount "$sd_boot_dir"
fi

sync
printf 'Installed extlinux selector assets from %s\n' "$repo_root"

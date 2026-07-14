#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-"$repo_root/build/uInitrd-orangepi4pro-bootselect"}
work=
busybox=/usr/lib/initramfs-tools/bin/busybox

# Dry-run mode for CI: outputs expected strings without requiring native tools
dry_run=${dry_run:-false}

cleanup() {
  if [ -n "${work:-}" ]; then
    rm -rf "$work"
  fi
}
trap cleanup EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ "$dry_run" = "true" ]; then
  printf 'Built %s\n' "$out"
  printf 'dry_run=true\n'
  exit 0
fi

command -v mkimage >/dev/null 2>&1 || fail 'mkimage is required'
command -v cpio >/dev/null 2>&1 || fail 'cpio is required'
command -v gzip >/dev/null 2>&1 || fail 'gzip is required'
command -v gcc >/dev/null 2>&1 || fail 'gcc is required'
[ -x "$busybox" ] || fail "busybox not found: $busybox"

work=$(mktemp -d)
root="$work/root"
mkdir -p "$root/bin" "$root/sbin" "$root/lib/aarch64-linux-gnu" "$root/lib" \
  "$root/proc" "$root/sys" "$root/dev" "$root/mnt" "$root/newroot"

install -m 0755 "$busybox" "$root/bin/busybox"
install -m 0755 "$repo_root/initramfs/bootselect-init" "$root/init"
gcc -Os -s -Wall -Wextra -o "$root/bin/fb-bootselect" "$repo_root/tools/fb-bootselect.c"
gcc -Os -s -Wall -Wextra -I/usr/include/drm \
  -o "$root/bin/kms-bootselect" "$repo_root/tools/kms-bootselect.c"

while IFS= read -r applet; do
  case "$applet" in
    awk|cat|cmp|cp|cut|date|echo|grep|ln|ls|mkdir|mount|mv|printf|readlink|reboot|rm|sed|sh|sleep|stty|sync|tail|test|touch|umount|switch_root|'[')
      ln -s busybox "$root/bin/$applet"
      ;;
  esac
done < <("$busybox" --list)
ln -s ../bin/busybox "$root/sbin/reboot"
ln -s ../bin/busybox "$root/sbin/switch_root"

install -m 0644 /lib/aarch64-linux-gnu/libc.so.6 "$root/lib/aarch64-linux-gnu/libc.so.6"
install -m 0755 /lib/ld-linux-aarch64.so.1 "$root/lib/ld-linux-aarch64.so.1"

mkdir -p "$(dirname "$out")"
(
  cd "$root"
  find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -9 > "$work/initramfs.cpio.gz"
)
mkimage -A arm -O linux -T ramdisk -C gzip -n 'Orange Pi 4 Pro boot selector initramfs' \
  -d "$work/initramfs.cpio.gz" "$out" >/dev/null

printf 'Built %s\n' "$out"
sha256sum "$out"

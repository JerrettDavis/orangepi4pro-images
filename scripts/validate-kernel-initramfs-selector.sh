#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact=${1:-"$repo_root/build/uInitrd-orangepi4pro-bootselect"}
work=

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

bash -n "$repo_root/scripts/build-kernel-initramfs-selector.sh"
sh -n "$repo_root/initramfs/bootselect-init"

grep -q 'kernel_selector_first' "$repo_root/configs/boot.cmd" \
  || fail 'boot.cmd missing kernel_selector_first switch'
grep -q 'uInitrd-orangepi4pro-bootselect' "$repo_root/configs/boot.cmd" \
  || fail 'boot.cmd missing selector initrd name'
grep -q '^kernel_selector_first=false$' "$repo_root/configs/orangepiEnv.txt" \
  || fail 'default env must keep kernel selector disabled'

if [ -f "$artifact" ]; then
  file "$artifact" | grep -q 'u-boot legacy uImage' \
    || fail "selector artifact is not a legacy uInitrd: $artifact"
  work=$(mktemp -d)
  dd if="$artifact" of="$work/initramfs.cpio.gz" bs=64 skip=1 status=none
  gzip -dc "$work/initramfs.cpio.gz" | (cd "$work" && cpio -id --quiet)
  grep -q 'Orange Pi 4 Pro Boot Selector' "$work/init" \
    || fail 'selector menu text missing from artifact'
  [ -x "$work/bin/busybox" ] || fail 'busybox missing from selector artifact'
  [ -x "$work/bin/fb-bootselect" ] || fail 'framebuffer painter missing from selector artifact'
  [ -e "$work/bin/reboot" ] || fail 'reboot applet missing from selector artifact'
fi

printf 'Kernel initramfs selector validation passed.\n'

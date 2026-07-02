#!/usr/bin/env bash
set -euo pipefail

sd_mount=${1:-/mnt/opisd-ro}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

printf 'Validating active Orange Pi boot source markers\n\n'

printf 'Kernel command line:\n'
cat /proc/cmdline
printf '\n\n'

if grep -qw 'bootchooser=extlinux-legacy-nvme' /proc/cmdline; then
  printf 'Current boot came through extlinux NVMe entry.\n'
elif grep -qw 'bootchooser=extlinux-legacy-sd' /proc/cmdline; then
  printf 'Current boot came through extlinux SD entry.\n'
elif grep -qw 'bootchooser=legacy-bootm-fallback' /proc/cmdline; then
  printf 'Current boot used the updated legacy bootm fallback.\n'
elif grep -qw 'bootchooser=uboot-bootmenu-nvme' /proc/cmdline; then
  printf 'Current boot came through U-Boot bootmenu NVMe entry.\n'
elif grep -qw 'bootchooser=uboot-bootmenu-sd' /proc/cmdline; then
  printf 'Current boot came through U-Boot bootmenu SD entry.\n'
elif grep -qw 'bootchooser=uboot-bootmenu-nvme-verbose' /proc/cmdline; then
  printf 'Current boot came through U-Boot bootmenu verbose NVMe entry.\n'
elif grep -qw 'bootchooser=uboot-bootmenu-nosel' /proc/cmdline; then
  printf 'Current boot entered U-Boot bootmenu but returned without a selection.\n'
else
  printf 'Current boot has no bootchooser marker; U-Boot likely used an older boot.scr.\n'
fi

printf '\nMounted boot filesystems:\n'
findmnt / /boot /boot/efi "$sd_mount" -o TARGET,SOURCE,FSTYPE,OPTIONS --noheadings 2>/dev/null || true

if [ -d "$sd_mount/boot" ]; then
  printf '\nChecking SD boot script at %s/boot\n' "$sd_mount"
  grep -q '^extlinux_first=true$' "$sd_mount/boot/orangepiEnv.txt" \
    || fail "SD orangepiEnv.txt does not enable extlinux_first"
  grep -q '^bootmenu_first=true$' "$sd_mount/boot/orangepiEnv.txt" \
    || fail "SD orangepiEnv.txt does not enable bootmenu_first"
  grep -q '^selector_console=true$' "$sd_mount/boot/orangepiEnv.txt" \
    || fail "SD orangepiEnv.txt does not force selector console output"
  grep -q '^selector_bitmap=true$' "$sd_mount/boot/orangepiEnv.txt" \
    || fail "SD orangepiEnv.txt does not enable selector bitmap"
  test -e "$sd_mount/boot/boot.bmp" \
    || fail "SD selector boot.bmp missing"
  strings "$sd_mount/boot/boot.scr" | grep -q 'bootchooser=legacy-bootm-fallback' \
    || fail "SD boot.scr lacks the updated fallback marker"
  strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-bootmenu-nvme' \
    || fail "SD boot.scr lacks the U-Boot NVMe bootmenu marker"
  strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-bootmenu-nosel' \
    || fail "SD boot.scr lacks the U-Boot bootmenu no-selection marker"
  strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-bootmenu-sd' \
    || fail "SD boot.scr lacks the U-Boot SD bootmenu marker"
  # shellcheck disable=SC2016
  strings "$sd_mount/boot/boot.scr" | grep -Eq 'sysboot( -p)? [$][{]devtype[}] [$][{]devnum[}]:[$][{]distro_bootpart[}] any' \
    || fail "SD boot.scr lacks the partition-qualified sysboot probe"
  test -e "$sd_mount/boot/extlinux/extlinux.conf" \
    || fail "SD extlinux.conf missing"
  test -e "$sd_mount/boot/uImage-5.15.147-sun60iw2" \
    || fail "SD stock uImage missing"
  test -e "$sd_mount/boot/uImage-5.15.147-sun60iw2-cyberdeck" \
    || fail "SD cyberdeck uImage missing"
fi

printf '\nActive boot source validation completed.\n'

#!/usr/bin/env bash
set -euo pipefail

sd_mount=${1:-/mnt/opisd-ro}
expected_bootmenu_first=${EXPECTED_BOOTMENU_FIRST:-any}
expected_selector_console=${EXPECTED_SELECTOR_CONSOLE:-any}
expected_selector_bitmap=${EXPECTED_SELECTOR_BITMAP:-any}
expected_selector_visual_test=${EXPECTED_SELECTOR_VISUAL_TEST:-any}
expected_selector_visual_hold=${EXPECTED_SELECTOR_VISUAL_HOLD:-any}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

printf 'Validating active Orange Pi boot source markers\n\n'

printf 'Kernel command line:\n'
cat /proc/cmdline
printf '\n\n'

if grep -q 'bootchooser=extlinux-legacy-nvme' /proc/cmdline; then
  printf 'Current boot came through extlinux NVMe entry.\n'
elif grep -q 'bootchooser=extlinux-legacy-sd' /proc/cmdline; then
  printf 'Current boot came through extlinux SD entry.\n'
elif grep -q 'bootchooser=uboot-bootmenu-nvme' /proc/cmdline; then
  printf 'Current boot came through U-Boot bootmenu NVMe entry.\n'
elif grep -q 'bootchooser=uboot-bootmenu-sd' /proc/cmdline; then
  printf 'Current boot came through U-Boot bootmenu SD entry.\n'
elif grep -q 'bootchooser=uboot-bootmenu-nosel' /proc/cmdline; then
  printf 'Current boot entered U-Boot bootmenu but returned without a selection.\n'
elif grep -q 'bootchooser=legacy-bootm-fallback' /proc/cmdline; then
  printf 'Current boot used the updated legacy bootm fallback.\n'
elif grep -q 'bootchooser=boot-script-default-nvme' /proc/cmdline; then
  printf 'Current boot used the boot-script default NVMe path.\n'
elif grep -q 'bootchooser=uboot-logo-preinit-ok' /proc/cmdline; then
  printf 'Current boot ran the U-Boot logo preinit path before Linux.\n'
else
  printf 'Current boot has no bootchooser marker; U-Boot likely used an older boot.scr.\n'
fi

printf '\nMounted boot filesystems:\n'
findmnt / /boot /boot/efi "$sd_mount" -o TARGET,SOURCE,FSTYPE,OPTIONS --noheadings 2>/dev/null || true

if [ -d "$sd_mount/boot" ]; then
  printf '\nChecking SD boot script at %s/boot\n' "$sd_mount"
  if [ "$expected_bootmenu_first" != any ]; then
    grep -q "^bootmenu_first=${expected_bootmenu_first}$" "$sd_mount/boot/orangepiEnv.txt" \
      || fail "SD orangepiEnv.txt does not set bootmenu_first=${expected_bootmenu_first}"
  fi
  if [ "$expected_selector_console" != any ]; then
    grep -q "^selector_console=${expected_selector_console}$" "$sd_mount/boot/orangepiEnv.txt" \
      || fail "SD orangepiEnv.txt does not set selector_console=${expected_selector_console}"
  fi
  if [ "$expected_selector_bitmap" != any ]; then
    grep -q "^selector_bitmap=${expected_selector_bitmap}$" "$sd_mount/boot/orangepiEnv.txt" \
      || fail "SD orangepiEnv.txt does not set selector_bitmap=${expected_selector_bitmap}"
  fi
  if [ "$expected_selector_visual_test" != any ]; then
    grep -q "^selector_visual_test=${expected_selector_visual_test}$" "$sd_mount/boot/orangepiEnv.txt" \
      || fail "SD orangepiEnv.txt does not set selector_visual_test=${expected_selector_visual_test}"
  fi
  if [ "$expected_selector_visual_hold" != any ]; then
    grep -q "^selector_visual_hold=${expected_selector_visual_hold}$" "$sd_mount/boot/orangepiEnv.txt" \
      || fail "SD orangepiEnv.txt does not set selector_visual_hold=${expected_selector_visual_hold}"
  fi
  strings "$sd_mount/boot/boot.scr" | grep -q 'bootchooser=legacy-bootm-fallback' \
    || fail "SD boot.scr is the recovered direct bootm script, without selector fallback marker"
  if [ "$expected_selector_visual_test" = hdmi20_pattern ]; then
    ! strings "$sd_mount/boot/boot.scr" | grep -q 'sunxi_drm reinit' \
      || fail "SD boot.scr still references the disabled DRM reinit diagnostic"
    strings "$sd_mount/boot/boot.scr" | grep -q 'drmreinit=disabled' \
      || fail "SD boot.scr lacks the disabled DRM reinit marker"
    strings "$sd_mount/boot/boot.scr" | grep -q 'opi_drmre_' \
      || fail "SD boot.scr lacks the DRM reinit bootarg diagnostic"
    strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-visual-hdmi20-pattern-ok' \
      || fail "SD boot.scr lacks the HDMI20 visual-test marker"
  fi
  if [ "$expected_bootmenu_first" = true ]; then
    strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-bootmenu-nvme' \
      || fail "SD boot.scr lacks the U-Boot NVMe bootmenu marker"
    strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-bootmenu-nosel' \
      || fail "SD boot.scr lacks the U-Boot bootmenu no-selection marker"
    strings "$sd_mount/boot/boot.scr" | grep -q 'uboot-bootmenu-sd' \
      || fail "SD boot.scr lacks the U-Boot SD bootmenu marker"
    # shellcheck disable=SC2016
    strings "$sd_mount/boot/boot.scr" | grep -Eq 'sysboot( -p)? [$][{]devtype[}] [$][{]devnum[}]:[$][{]distro_bootpart[}] any' \
      || fail "SD boot.scr lacks the partition-qualified sysboot probe"
  fi
  test -e "$sd_mount/boot/extlinux/extlinux.conf" \
    || fail "SD extlinux.conf missing"
  test -e "$sd_mount/boot/uImage-5.15.147-sun60iw2" \
    || fail "SD stock uImage missing"
  test -e "$sd_mount/boot/uImage-5.15.147-sun60iw2-cyberdeck" \
    || fail "SD cyberdeck uImage missing"
fi

printf '\nActive boot source validation completed.\n'

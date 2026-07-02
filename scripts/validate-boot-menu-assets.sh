#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ] && [ -d /boot/efi ] && ! [ -x /boot/efi ]; then
  printf 'ERROR: /boot/efi is not accessible by this user; rerun with sudo\n' >&2
  exit 1
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [ -e "$1" ] || fail "missing $1"
}

printf 'Validating Orange Pi 4 Pro GRUB/extlinux boot-menu assets\n\n'

for file in \
  /boot/boot.cmd \
  /boot/boot.scr \
  /boot/orangepiEnv.txt \
  /boot/grub/grub.cfg \
  /boot/extlinux/extlinux.conf \
  /boot/efi/EFI/BOOT/BOOTAA64.EFI \
  /boot/efi/EFI/orangepi/grubaa64.efi \
  /boot/EFI/BOOT/BOOTAA64.EFI \
  /boot/efi/uImage-5.15.147-sun60iw2-cyberdeck \
  /boot/efi/uInitrd-5.15.147-sun60iw2-cyberdeck \
  /boot/efi/uImage-5.15.147-sun60iw2 \
  /boot/efi/uInitrd-5.15.147-sun60iw2 \
  /boot/efi/Image-5.15.147-sun60iw2-cyberdeck \
  /boot/efi/initrd.img-5.15.147-sun60iw2-cyberdeck \
  /boot/efi/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb \
  /boot/efi/vmlinux-5.15.147-sun60iw2 \
  /boot/efi/initrd.img-5.15.147-sun60iw2 \
  /boot/efi/dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb \
  /boot/Image-5.15.147-sun60iw2-cyberdeck \
  /boot/initrd.img-5.15.147-sun60iw2-cyberdeck \
  /boot/uImage-5.15.147-sun60iw2-cyberdeck \
  /boot/uInitrd-5.15.147-sun60iw2-cyberdeck \
  /boot/uImage-5.15.147-sun60iw2 \
  /boot/uInitrd-5.15.147-sun60iw2 \
  /boot/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb \
  /boot/vmlinux-5.15.147-sun60iw2 \
  /boot/initrd.img-5.15.147-sun60iw2 \
  /boot/dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb; do
  require_file "$file"
done

grub-script-check /boot/grub/grub.cfg

grep -q '^grub_first=false$' /boot/orangepiEnv.txt || fail 'grub_first should be disabled after failed reboot tests'
grep -q '^extlinux_first=true$' /boot/orangepiEnv.txt || fail 'extlinux_first should be enabled for legacy-image menu test'
grep -q '^direct_booti_first=false$' /boot/orangepiEnv.txt || fail 'direct_booti_first should be disabled after failed reboot tests'
grep -q 'bootefi' /boot/boot.cmd || fail 'boot.cmd does not contain GRUB EFI handoff'
grep -q 'sysboot' /boot/boot.cmd || fail 'boot.cmd does not contain extlinux handoff'
grep -q 'booti' /boot/boot.cmd || fail 'boot.cmd does not contain direct booti probe'
grep -q 'bootm' /boot/boot.cmd || fail 'boot.cmd does not contain legacy fallback'

grep -q 'Ubuntu NVMe - cyberdeck kernel' /boot/grub/grub.cfg || fail 'GRUB NVMe menu entry missing'
grep -q 'Ubuntu SD - stock kernel' /boot/grub/grub.cfg || fail 'GRUB SD menu entry missing'
grep -q 'Ubuntu NVMe - cyberdeck kernel' /boot/extlinux/extlinux.conf || fail 'extlinux NVMe menu entry missing'
grep -q 'Ubuntu SD - stock kernel' /boot/extlinux/extlinux.conf || fail 'extlinux SD menu entry missing'

grep -q 'eb86cfeb-60c7-4513-bc69-f6d28e9d561b' /boot/grub/grub.cfg /boot/extlinux/extlinux.conf \
  || fail 'NVMe root UUID missing from boot menus'
grep -q 'dc683cb4-0847-4d2f-83f1-184d35749d4c' /boot/grub/grub.cfg /boot/extlinux/extlinux.conf \
  || fail 'SD root UUID missing from boot menus'
grep -q 'bootchooser=extlinux-legacy-nvme' /boot/extlinux/extlinux.conf || fail 'extlinux NVMe marker missing'
grep -q 'bootchooser=extlinux-legacy-sd' /boot/extlinux/extlinux.conf || fail 'extlinux SD marker missing'
grep -q '/uImage-5.15.147-sun60iw2-cyberdeck' /boot/extlinux/extlinux.conf || fail 'extlinux must use legacy cyberdeck uImage'
grep -q '/uImage-5.15.147-sun60iw2' /boot/extlinux/extlinux.conf || fail 'extlinux must use legacy stock uImage'

printf 'Hashes for mirrored files:\n'
sha256sum \
  /boot/efi/EFI/BOOT/BOOTAA64.EFI \
  /boot/EFI/BOOT/BOOTAA64.EFI \
  /boot/grub/grub.cfg \
  /boot/efi/EFI/BOOT/grub.cfg \
  /boot/EFI/BOOT/grub.cfg \
  /boot/extlinux/extlinux.conf \
  /boot/efi/extlinux/extlinux.conf \
  /boot/boot.scr \
  /boot/efi/boot.scr

printf '\nBoot-menu asset validation passed.\n'

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

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
expected_extlinux_default=${EXPECTED_EXTLINUX_DEFAULT:-ubuntu-nvme}

for file in \
  /boot/boot.cmd \
  /boot/boot.scr \
  /boot/orangepiEnv.txt \
  /boot/extlinux/extlinux.conf \
  /boot/uImage-5.15.147-sun60iw2-cyberdeck \
  /boot/uInitrd-5.15.147-sun60iw2-cyberdeck \
  /boot/uImage-5.15.147-sun60iw2 \
  /boot/uInitrd-5.15.147-sun60iw2 \
  /boot/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb \
  /boot/dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb; do
  require_file "$file"
done

if [ -e /boot/grub/grub.cfg ]; then
  grub-script-check /boot/grub/grub.cfg
fi

grep -q '^grub_first=false$' /boot/orangepiEnv.txt || fail 'grub_first should be disabled after failed reboot tests'
grep -q '^extlinux_first=true$' /boot/orangepiEnv.txt || fail 'extlinux_first should be enabled for legacy-image menu test'
grep -q '^direct_booti_first=false$' /boot/orangepiEnv.txt || fail 'direct_booti_first should be disabled after failed reboot tests'
grep -q 'bootefi' /boot/boot.cmd || fail 'boot.cmd does not contain GRUB EFI handoff'
grep -q 'sysboot' /boot/boot.cmd || fail 'boot.cmd does not contain extlinux handoff'
grep -q 'booti' /boot/boot.cmd || fail 'boot.cmd does not contain direct booti probe'
grep -q 'bootm' /boot/boot.cmd || fail 'boot.cmd does not contain legacy fallback'

grep -q 'Ubuntu NVMe - cyberdeck kernel' /boot/extlinux/extlinux.conf || fail 'extlinux NVMe menu entry missing'
grep -q 'Ubuntu SD - stock kernel' /boot/extlinux/extlinux.conf || fail 'extlinux SD menu entry missing'
grep -q '^PROMPT 0$' /boot/extlinux/extlinux.conf || fail 'extlinux prompt should be disabled for stock U-Boot'
grep -q '^TIMEOUT 30$' /boot/extlinux/extlinux.conf || fail 'extlinux should use bounded 3 second timeout'
grep -q "^DEFAULT ${expected_extlinux_default}$" /boot/extlinux/extlinux.conf \
  || fail "extlinux default should be ${expected_extlinux_default}"

grep -q 'eb86cfeb-60c7-4513-bc69-f6d28e9d561b' /boot/extlinux/extlinux.conf \
  || fail 'NVMe root UUID missing from boot menus'
grep -q 'dc683cb4-0847-4d2f-83f1-184d35749d4c' /boot/extlinux/extlinux.conf \
  || fail 'SD root UUID missing from boot menus'
grep -q 'bootchooser=extlinux-legacy-nvme' /boot/extlinux/extlinux.conf || fail 'extlinux NVMe marker missing'
grep -q 'bootchooser=extlinux-legacy-sd' /boot/extlinux/extlinux.conf || fail 'extlinux SD marker missing'
grep -q 'bootchooser=legacy-bootm-fallback' /boot/boot.cmd || fail 'legacy fallback marker missing from boot.cmd'
# shellcheck disable=SC2016
grep -Fq 'sysboot ${devtype} ${devnum}:${distro_bootpart} any' /boot/boot.cmd \
  || fail 'boot.cmd should use partition-qualified non-prompted sysboot'
grep -q '^  LINUX ../uImage-5.15.147-sun60iw2-cyberdeck$' /boot/extlinux/extlinux.conf \
  || fail 'extlinux must use parent-relative legacy cyberdeck uImage path'
grep -q '^  LINUX ../uImage-5.15.147-sun60iw2$' /boot/extlinux/extlinux.conf \
  || fail 'extlinux must use parent-relative legacy stock uImage path'

cmp -s "$repo_root/configs/boot.cmd" /boot/boot.cmd || fail '/boot/boot.cmd differs from configs/boot.cmd'
cmp -s "$repo_root/configs/orangepiEnv.txt" /boot/orangepiEnv.txt \
  || fail '/boot/orangepiEnv.txt differs from configs/orangepiEnv.txt'
repo_extlinux_cmp=$(mktemp)
boot_extlinux_cmp=$(mktemp)
trap 'rm -f "$repo_extlinux_cmp" "$boot_extlinux_cmp"' EXIT
sed -E "s/^DEFAULT .*/DEFAULT ${expected_extlinux_default}/" \
  "$repo_root/configs/extlinux.conf" > "$repo_extlinux_cmp"
sed -E "s/^DEFAULT .*/DEFAULT ${expected_extlinux_default}/" \
  /boot/extlinux/extlinux.conf > "$boot_extlinux_cmp"
cmp -s "$repo_extlinux_cmp" "$boot_extlinux_cmp" \
  || fail '/boot/extlinux/extlinux.conf differs from configs/extlinux.conf beyond allowed DEFAULT override'

printf 'Hashes for mirrored files:\n'
hash_files=(
  /boot/extlinux/extlinux.conf
  /boot/boot.scr
)
for optional_file in \
  /boot/efi/extlinux/extlinux.conf \
  /boot/efi/boot.scr \
  /boot/grub/grub.cfg \
  /boot/EFI/BOOT/BOOTAA64.EFI \
  /boot/EFI/BOOT/grub.cfg \
  /boot/efi/EFI/BOOT/BOOTAA64.EFI \
  /boot/efi/EFI/BOOT/grub.cfg; do
  [ -e "$optional_file" ] && hash_files+=("$optional_file")
done
sha256sum "${hash_files[@]}"

printf '\nBoot-menu asset validation passed.\n'

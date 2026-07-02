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
expected_extlinux_prompt=${EXPECTED_EXTLINUX_PROMPT:-0}
expected_extlinux_timeout=${EXPECTED_EXTLINUX_TIMEOUT:-30}
expected_selector_console=${EXPECTED_SELECTOR_CONSOLE:-false}
expected_selector_prompt=${EXPECTED_SELECTOR_PROMPT:-false}
expected_selector_bitmap=${EXPECTED_SELECTOR_BITMAP:-false}
expected_bootlogo=${EXPECTED_BOOTLOGO:-true}
expected_logo=${EXPECTED_LOGO:-enabled}
expected_bootmenu_first=${EXPECTED_BOOTMENU_FIRST:-true}
expected_bootmenu_timeout=${EXPECTED_BOOTMENU_TIMEOUT:-10}

for file in \
  /boot/boot.cmd \
  /boot/boot.scr \
  /boot/orangepiEnv.txt \
  /boot/extlinux/extlinux.conf \
  /boot/boot.bmp \
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
grep -q "^bootmenu_first=${expected_bootmenu_first}$" /boot/orangepiEnv.txt \
  || fail "bootmenu_first should be ${expected_bootmenu_first}"
grep -q "^bootmenu_timeout=${expected_bootmenu_timeout}$" /boot/orangepiEnv.txt \
  || fail "bootmenu_timeout should be ${expected_bootmenu_timeout}"
grep -q "^selector_console=${expected_selector_console}$" /boot/orangepiEnv.txt \
  || fail "selector_console should be ${expected_selector_console}"
grep -q "^selector_prompt=${expected_selector_prompt}$" /boot/orangepiEnv.txt \
  || fail "selector_prompt should be ${expected_selector_prompt}"
grep -q "^selector_bitmap=${expected_selector_bitmap}$" /boot/orangepiEnv.txt \
  || fail "selector_bitmap should be ${expected_selector_bitmap}"
grep -q "^bootlogo=${expected_bootlogo}$" /boot/orangepiEnv.txt \
  || fail "bootlogo should be ${expected_bootlogo}"
grep -q "^logo=${expected_logo}$" /boot/orangepiEnv.txt \
  || fail "logo should be ${expected_logo}"
grep -q 'bootefi' /boot/boot.cmd || fail 'boot.cmd does not contain GRUB EFI handoff'
grep -q 'bootmenu' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot bootmenu handoff'
grep -q 'uboot-bootmenu-nosel' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot bootmenu no-selection marker'
grep -q 'uboot-bootmenu-nvme' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot NVMe selector marker'
grep -q 'uboot-bootmenu-sd' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot SD selector marker'
grep -q 'sysboot' /boot/boot.cmd || fail 'boot.cmd does not contain extlinux handoff'
grep -q 'booti' /boot/boot.cmd || fail 'boot.cmd does not contain direct booti probe'
grep -q 'bootm' /boot/boot.cmd || fail 'boot.cmd does not contain legacy fallback'
grep -q 'Forcing selector output to serial and video console' /boot/boot.cmd \
  || fail 'boot.cmd does not contain selector console override'
grep -q 'sysboot -p' /boot/boot.cmd || fail 'boot.cmd does not contain prompted sysboot path'
! grep -q '^[[:space:]]*sunxi_show_bmp boot.bmp' /boot/boot.cmd \
  || fail 'boot.cmd must not call unsafe sunxi_show_bmp from boot.scr'

grep -q 'Ubuntu NVMe - cyberdeck kernel' /boot/extlinux/extlinux.conf || fail 'extlinux NVMe menu entry missing'
grep -q 'Ubuntu SD - stock kernel' /boot/extlinux/extlinux.conf || fail 'extlinux SD menu entry missing'
grep -q "^PROMPT ${expected_extlinux_prompt}$" /boot/extlinux/extlinux.conf \
  || fail "extlinux prompt should be ${expected_extlinux_prompt}"
grep -q "^TIMEOUT ${expected_extlinux_timeout}$" /boot/extlinux/extlinux.conf \
  || fail "extlinux timeout should be ${expected_extlinux_timeout}"
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
repo_env_cmp=$(mktemp)
boot_env_cmp=$(mktemp)
repo_extlinux_cmp=$(mktemp)
boot_extlinux_cmp=$(mktemp)
trap 'rm -f "$repo_env_cmp" "$boot_env_cmp" "$repo_extlinux_cmp" "$boot_extlinux_cmp"' EXIT
sed -E "s/^selector_console=.*/selector_console=${expected_selector_console}/" \
  "$repo_root/configs/orangepiEnv.txt" \
  | sed -E "s/^selector_prompt=.*/selector_prompt=${expected_selector_prompt}/" \
  | sed -E "s/^selector_bitmap=.*/selector_bitmap=${expected_selector_bitmap}/" \
  | sed -E "s/^bootlogo=.*/bootlogo=${expected_bootlogo}/" \
  | sed -E "s/^logo=.*/logo=${expected_logo}/" \
  | sed -E "s/^bootmenu_first=.*/bootmenu_first=${expected_bootmenu_first}/" \
  | sed -E "s/^bootmenu_timeout=.*/bootmenu_timeout=${expected_bootmenu_timeout}/" \
  > "$repo_env_cmp"
sed -E "s/^selector_console=.*/selector_console=${expected_selector_console}/" \
  /boot/orangepiEnv.txt \
  | sed -E "s/^selector_prompt=.*/selector_prompt=${expected_selector_prompt}/" \
  | sed -E "s/^selector_bitmap=.*/selector_bitmap=${expected_selector_bitmap}/" \
  | sed -E "s/^bootlogo=.*/bootlogo=${expected_bootlogo}/" \
  | sed -E "s/^logo=.*/logo=${expected_logo}/" \
  | sed -E "s/^bootmenu_first=.*/bootmenu_first=${expected_bootmenu_first}/" \
  | sed -E "s/^bootmenu_timeout=.*/bootmenu_timeout=${expected_bootmenu_timeout}/" \
  > "$boot_env_cmp"
cmp -s "$repo_env_cmp" "$boot_env_cmp" \
  || fail '/boot/orangepiEnv.txt differs from configs/orangepiEnv.txt beyond allowed prompt-test overrides'
sed -E "s/^DEFAULT .*/DEFAULT ${expected_extlinux_default}/" \
  "$repo_root/configs/extlinux.conf" \
  | sed -E "s/^PROMPT .*/PROMPT ${expected_extlinux_prompt}/" \
  | sed -E "s/^TIMEOUT .*/TIMEOUT ${expected_extlinux_timeout}/" \
  > "$repo_extlinux_cmp"
sed -E "s/^DEFAULT .*/DEFAULT ${expected_extlinux_default}/" \
  /boot/extlinux/extlinux.conf \
  | sed -E "s/^PROMPT .*/PROMPT ${expected_extlinux_prompt}/" \
  | sed -E "s/^TIMEOUT .*/TIMEOUT ${expected_extlinux_timeout}/" \
  > "$boot_extlinux_cmp"
cmp -s "$repo_extlinux_cmp" "$boot_extlinux_cmp" \
  || fail '/boot/extlinux/extlinux.conf differs from configs/extlinux.conf beyond allowed prompt/timeout/default overrides'

printf 'Hashes for mirrored files:\n'
hash_files=(
  /boot/extlinux/extlinux.conf
  /boot/boot.scr
  /boot/boot.bmp
)
for optional_file in \
  /boot/efi/extlinux/extlinux.conf \
  /boot/efi/boot.scr \
  /boot/efi/boot.bmp \
  /boot/grub/grub.cfg \
  /boot/EFI/BOOT/BOOTAA64.EFI \
  /boot/EFI/BOOT/grub.cfg \
  /boot/efi/EFI/BOOT/BOOTAA64.EFI \
  /boot/efi/EFI/BOOT/grub.cfg; do
  [ -e "$optional_file" ] && hash_files+=("$optional_file")
done
sha256sum "${hash_files[@]}"

printf '\nBoot-menu asset validation passed.\n'

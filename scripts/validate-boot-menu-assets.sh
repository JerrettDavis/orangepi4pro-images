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
expected_extlinux_prompt=${EXPECTED_EXTLINUX_PROMPT:-1}
expected_extlinux_timeout=${EXPECTED_EXTLINUX_TIMEOUT:-200}
expected_selector_console=${EXPECTED_SELECTOR_CONSOLE:-false}
expected_selector_prompt=${EXPECTED_SELECTOR_PROMPT:-true}
expected_selector_bitmap=${EXPECTED_SELECTOR_BITMAP:-false}
expected_selector_visual_test=${EXPECTED_SELECTOR_VISUAL_TEST:-none}
expected_selector_visual_hold=${EXPECTED_SELECTOR_VISUAL_HOLD:-3}
expected_selector_logo_preinit=${EXPECTED_SELECTOR_LOGO_PREINIT:-true}
expected_selector_logo_command=${EXPECTED_SELECTOR_LOGO_COMMAND:-sunxi_show_logo}
expected_selector_logo_hold=${EXPECTED_SELECTOR_LOGO_HOLD:-15}
expected_selector_diag_force_bootm=${EXPECTED_SELECTOR_DIAG_FORCE_BOOTM:-false}
expected_bootlogo=${EXPECTED_BOOTLOGO:-true}
expected_logo=${EXPECTED_LOGO:-enabled}
expected_extlinux_first=${EXPECTED_EXTLINUX_FIRST:-true}
expected_bootmenu_first=${EXPECTED_BOOTMENU_FIRST:-false}
expected_bootmenu_timeout=${EXPECTED_BOOTMENU_TIMEOUT:-200}
expected_bootmenu_default=${EXPECTED_BOOTMENU_DEFAULT:-nvme}
expected_kernel_selector_first=${EXPECTED_KERNEL_SELECTOR_FIRST:-false}
expected_kernel_selector_timeout=${EXPECTED_KERNEL_SELECTOR_TIMEOUT:-10}
expected_bootgui_selector=${EXPECTED_BOOTGUI_SELECTOR:-false}
expected_bootgui_selector_timeout=${EXPECTED_BOOTGUI_SELECTOR_TIMEOUT:-10}

for file in \
  /boot/boot.cmd \
  /boot/boot.scr \
  /boot/orangepiEnv.txt \
  /boot/extlinux/extlinux.conf \
  /boot/bootlogo.bmp \
  /boot/boot.bmp \
  /boot/boot1.bmp \
  /boot/fastbootlogo.bmp \
  /boot/uImage-5.15.147-sun60iw2-cyberdeck \
  /boot/uInitrd-5.15.147-sun60iw2-cyberdeck \
  /boot/uImage-5.15.147-sun60iw2 \
  /boot/uInitrd-5.15.147-sun60iw2 \
  /boot/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb \
  /boot/dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb; do
  require_file "$file"
done

if [ "$expected_kernel_selector_first" = true ]; then
  require_file /boot/uInitrd-orangepi4pro-bootselect
  "$repo_root/scripts/validate-kernel-initramfs-selector.sh" /boot/uInitrd-orangepi4pro-bootselect
  if [ -d /boot/efi ]; then
    require_file /boot/efi/uInitrd-orangepi4pro-bootselect
    cmp -s /boot/uInitrd-orangepi4pro-bootselect /boot/efi/uInitrd-orangepi4pro-bootselect \
      || fail '/boot/efi selector initrd differs from /boot selector initrd'
    cmp -s /boot/boot.cmd /boot/efi/boot.cmd \
      || fail '/boot/efi/boot.cmd differs from /boot/boot.cmd'
    cmp -s /boot/boot.scr /boot/efi/boot.scr \
      || fail '/boot/efi/boot.scr differs from /boot/boot.scr'
    cmp -s /boot/orangepiEnv.txt /boot/efi/orangepiEnv.txt \
      || fail '/boot/efi/orangepiEnv.txt differs from /boot/orangepiEnv.txt'
    for file in \
      uImage-5.15.147-sun60iw2-cyberdeck \
      uInitrd-5.15.147-sun60iw2-cyberdeck \
      uImage-5.15.147-sun60iw2 \
      uInitrd-5.15.147-sun60iw2 \
      dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb \
      dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb; do
      require_file "/boot/efi/$file"
    done
  fi
fi

if [ -e /boot/grub/grub.cfg ]; then
  grub-script-check /boot/grub/grub.cfg
fi

grep -q '^grub_first=false$' /boot/orangepiEnv.txt || fail 'grub_first should be disabled after failed reboot tests'
grep -q "^extlinux_first=${expected_extlinux_first}$" /boot/orangepiEnv.txt \
  || fail "extlinux_first should be ${expected_extlinux_first}"
grep -q '^direct_booti_first=false$' /boot/orangepiEnv.txt || fail 'direct_booti_first should be disabled after failed reboot tests'
grep -q "^bootmenu_first=${expected_bootmenu_first}$" /boot/orangepiEnv.txt \
  || fail "bootmenu_first should be ${expected_bootmenu_first}"
grep -q "^bootmenu_timeout=${expected_bootmenu_timeout}$" /boot/orangepiEnv.txt \
  || fail "bootmenu_timeout should be ${expected_bootmenu_timeout}"
grep -q "^bootmenu_default=${expected_bootmenu_default}$" /boot/orangepiEnv.txt \
  || fail "bootmenu_default should be ${expected_bootmenu_default}"
grep -q "^kernel_selector_first=${expected_kernel_selector_first}$" /boot/orangepiEnv.txt \
  || fail "kernel_selector_first should be ${expected_kernel_selector_first}"
grep -q "^kernel_selector_timeout=${expected_kernel_selector_timeout}$" /boot/orangepiEnv.txt \
  || fail "kernel_selector_timeout should be ${expected_kernel_selector_timeout}"
grep -q "^bootgui_selector=${expected_bootgui_selector}$" /boot/orangepiEnv.txt \
  || fail "bootgui_selector should be ${expected_bootgui_selector}"
grep -q "^bootgui_selector_timeout=${expected_bootgui_selector_timeout}$" /boot/orangepiEnv.txt \
  || fail "bootgui_selector_timeout should be ${expected_bootgui_selector_timeout}"
cmp -s /boot/bootlogo.bmp /boot/boot.bmp || fail '/boot/bootlogo.bmp must mirror /boot/boot.bmp for A733 U-Boot logo loading'
cmp -s /boot/boot.bmp /boot/boot1.bmp || fail '/boot/boot1.bmp must mirror /boot/boot.bmp for A733 U-Boot logo loading'
cmp -s /boot/boot.bmp /boot/fastbootlogo.bmp || fail '/boot/fastbootlogo.bmp must mirror /boot/boot.bmp for A733 fast-logo loading'
grep -q "^selector_console=${expected_selector_console}$" /boot/orangepiEnv.txt \
  || fail "selector_console should be ${expected_selector_console}"
grep -q "^selector_prompt=${expected_selector_prompt}$" /boot/orangepiEnv.txt \
  || fail "selector_prompt should be ${expected_selector_prompt}"
grep -q "^selector_bitmap=${expected_selector_bitmap}$" /boot/orangepiEnv.txt \
  || fail "selector_bitmap should be ${expected_selector_bitmap}"
grep -q "^selector_visual_test=${expected_selector_visual_test}$" /boot/orangepiEnv.txt \
  || fail "selector_visual_test should be ${expected_selector_visual_test}"
grep -q "^selector_visual_hold=${expected_selector_visual_hold}$" /boot/orangepiEnv.txt \
  || fail "selector_visual_hold should be ${expected_selector_visual_hold}"
grep -q "^selector_logo_preinit=${expected_selector_logo_preinit}$" /boot/orangepiEnv.txt \
  || fail "selector_logo_preinit should be ${expected_selector_logo_preinit}"
grep -q "^selector_logo_command=${expected_selector_logo_command}$" /boot/orangepiEnv.txt \
  || fail "selector_logo_command should be ${expected_selector_logo_command}"
grep -q "^selector_logo_hold=${expected_selector_logo_hold}$" /boot/orangepiEnv.txt \
  || fail "selector_logo_hold should be ${expected_selector_logo_hold}"
grep -q "^selector_diag_force_bootm=${expected_selector_diag_force_bootm}$" /boot/orangepiEnv.txt \
  || fail "selector_diag_force_bootm should be ${expected_selector_diag_force_bootm}"
grep -q "^bootlogo=${expected_bootlogo}$" /boot/orangepiEnv.txt \
  || fail "bootlogo should be ${expected_bootlogo}"
grep -q "^logo=${expected_logo}$" /boot/orangepiEnv.txt \
  || fail "logo should be ${expected_logo}"
grep -q 'bootefi' /boot/boot.cmd || fail 'boot.cmd does not contain GRUB EFI handoff'
grep -q 'bootmenu' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot bootmenu handoff'
grep -q 'uboot-bootmenu-nosel' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot bootmenu no-selection marker'
grep -q 'uboot-bootmenu-nvme' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot NVMe selector marker'
grep -q 'uboot-bootmenu-sd' /boot/boot.cmd || fail 'boot.cmd does not contain U-Boot SD selector marker'
grep -q 'usb start' /boot/boot.cmd || fail 'boot.cmd does not start USB before bootmenu'
grep -q 'bootmenu_default' /boot/boot.cmd || fail 'boot.cmd does not support deterministic bootmenu default tests'
grep -q 'sunxi_drm colorbar' /boot/boot.cmd || fail 'boot.cmd does not support bounded colorbar visual test'
grep -q 'sunxi_drm fbtest' /boot/boot.cmd || fail 'boot.cmd does not support bounded framebuffer visual test'
grep -q 'sunxi_hdmi20 pattern 1' /boot/boot.cmd || fail 'boot.cmd does not support bounded HDMI20 pattern visual test'
grep -q 'sunxi_drm_env' /boot/boot.cmd || fail 'boot.cmd does not collect U-Boot DRM env diagnostics'
grep -q 'sunxi_hdmi_env' /boot/boot.cmd || fail 'boot.cmd does not collect U-Boot HDMI env diagnostics'
grep -q 'selector_logo_de' /boot/boot.cmd || fail 'boot.cmd does not collect logo-path DE/TCON diagnostics'
# shellcheck disable=SC2016
grep -q 'opi_logo_${selector_logo_de}' /boot/boot.cmd || fail 'boot.cmd does not preserve logo-path DE/TCON diagnostics'
grep -q 'opi_hdmi_secondpass' /boot/boot.cmd || fail 'boot.cmd does not preserve HDMI second-pass diagnostics'
grep -q 'opi_hdmi_drv_diag' /boot/boot.cmd || fail 'boot.cmd does not preserve HDMI driver-enable diagnostics'
grep -q 'opi_snps_phy_diag' /boot/boot.cmd || fail 'boot.cmd does not preserve SNPS PHY diagnostics'
grep -q 'opi_fastlogo_diag' /boot/boot.cmd || fail 'boot.cmd does not preserve fastlogo diagnostics'
grep -q 'sunxi_show_logo' /boot/boot.cmd || fail 'boot.cmd does not pre-initialize U-Boot video with stock logo command'
grep -q 'uboot-bootgui-logo-ok' /boot/boot.cmd || fail 'boot.cmd lacks BootGUI logo success marker'
grep -q 'uboot-logo-preinit-ok' /boot/boot.cmd || fail 'boot.cmd lacks logo preinit success marker'
grep -q 'uboot-bmp-display-ok' /boot/boot.cmd || fail 'boot.cmd lacks standard U-Boot bmp display success marker'
# shellcheck disable=SC2016
grep -q 'bmp display ${load_addr}' /boot/boot.cmd || fail 'boot.cmd lacks standard U-Boot bmp display path'
grep -q 'Forcing diagnostic legacy bootm after bitmap display test' /boot/boot.cmd \
  || fail 'boot.cmd lacks marker-preserving bitmap bootm diagnostic path'
grep -q 'selector_diag_force_bootm' /boot/boot.cmd || fail 'boot.cmd lacks diagnostic bootm path after logo preinit'
grep -q 'uboot-visual-colorbar-ok' /boot/boot.cmd || fail 'boot.cmd lacks colorbar success marker'
grep -q 'uboot-visual-fbtest-ok' /boot/boot.cmd || fail 'boot.cmd lacks fbtest success marker'
grep -q 'uboot-visual-hdmi20-pattern-ok' /boot/boot.cmd || fail 'boot.cmd lacks HDMI20 pattern success marker'
! grep -q 'sunxi_drm hdmi_recycle' /boot/boot.cmd \
  || fail 'boot.cmd must not contain unsafe HDMI recycle command'
grep -q 'orangepiBootOnce.txt' /boot/boot.cmd || fail 'boot.cmd does not import Linux selector bootonce requests'
grep -q 'bootchooser=linux-selector-sd' /boot/boot.cmd || fail 'boot.cmd lacks Linux selector SD marker'
grep -q 'bootchooser=linux-selector-nvme' /boot/boot.cmd || fail 'boot.cmd lacks Linux selector NVMe marker'
grep -q 'bootchooser=boot-script-default-nvme' /boot/boot.cmd || fail 'boot.cmd lacks boot-script default NVMe marker'
grep -q 'bootchooser=kernel-initramfs-selector' /boot/boot.cmd || fail 'boot.cmd lacks kernel initramfs selector marker'
grep -q 'uInitrd-orangepi4pro-bootselect' /boot/boot.cmd || fail 'boot.cmd lacks kernel initramfs selector initrd'
grep -q 'opi_bootselect' /boot/boot.cmd || fail 'boot.cmd lacks boot GUI selector command'
grep -q 'bootgui-selector-sd' /boot/boot.cmd || fail 'boot.cmd lacks boot GUI SD marker'
grep -q 'bootgui-selector-nvme' /boot/boot.cmd || fail 'boot.cmd lacks boot GUI NVMe marker'
grep -q 'sysboot' /boot/boot.cmd || fail 'boot.cmd does not contain extlinux handoff'
grep -q 'booti' /boot/boot.cmd || fail 'boot.cmd does not contain direct booti probe'
grep -q 'bootm' /boot/boot.cmd || fail 'boot.cmd does not contain legacy fallback'
grep -q 'Forcing selector output to serial and video console' /boot/boot.cmd \
  || fail 'boot.cmd does not contain selector console override'
grep -q 'sysboot -p' /boot/boot.cmd || fail 'boot.cmd does not contain prompted sysboot path'
! grep -q '^[[:space:]]*sunxi_show_bmp boot.bmp' /boot/boot.cmd \
  || fail 'boot.cmd must not call unsafe sunxi_show_bmp from boot.scr'
! awk '
  /Default boot target: NVMe Ubuntu/ { in_default = 1 }
  /if test -n "\$\{opi_bootselect_diag\}"/ { in_default = 0 }
  in_default && /setenv selector_visual_test none/ { found = 1 }
  END { exit found ? 0 : 1 }
' /boot/boot.cmd || fail 'default NVMe path must not clear staged selector_visual_test'

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
grep -q 'splash plymouth.ignore-serial-consoles' /boot/extlinux/extlinux.conf \
  || fail 'extlinux default entries must preserve Plymouth splash arguments'
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
  | sed -E "s/^selector_visual_test=.*/selector_visual_test=${expected_selector_visual_test}/" \
  | sed -E "s/^selector_visual_hold=.*/selector_visual_hold=${expected_selector_visual_hold}/" \
  | sed -E "s/^selector_logo_preinit=.*/selector_logo_preinit=${expected_selector_logo_preinit}/" \
  | sed -E "s/^selector_logo_command=.*/selector_logo_command=${expected_selector_logo_command}/" \
  | sed -E "s/^selector_logo_hold=.*/selector_logo_hold=${expected_selector_logo_hold}/" \
  | sed -E "s/^selector_diag_force_bootm=.*/selector_diag_force_bootm=${expected_selector_diag_force_bootm}/" \
  | sed -E "s/^bootlogo=.*/bootlogo=${expected_bootlogo}/" \
  | sed -E "s/^logo=.*/logo=${expected_logo}/" \
  | sed -E "s/^extlinux_first=.*/extlinux_first=${expected_extlinux_first}/" \
  | sed -E "s/^bootmenu_first=.*/bootmenu_first=${expected_bootmenu_first}/" \
  | sed -E "s/^bootmenu_timeout=.*/bootmenu_timeout=${expected_bootmenu_timeout}/" \
  | sed -E "s/^bootmenu_default=.*/bootmenu_default=${expected_bootmenu_default}/" \
  | sed -E "s/^kernel_selector_first=.*/kernel_selector_first=${expected_kernel_selector_first}/" \
  | sed -E "s/^kernel_selector_timeout=.*/kernel_selector_timeout=${expected_kernel_selector_timeout}/" \
  | sed -E "s/^bootgui_selector=.*/bootgui_selector=${expected_bootgui_selector}/" \
  | sed '/^$/d' \
  > "$repo_env_cmp"
sed -E "s/^selector_console=.*/selector_console=${expected_selector_console}/" \
  /boot/orangepiEnv.txt \
  | sed -E "s/^selector_prompt=.*/selector_prompt=${expected_selector_prompt}/" \
  | sed -E "s/^selector_bitmap=.*/selector_bitmap=${expected_selector_bitmap}/" \
  | sed -E "s/^selector_visual_test=.*/selector_visual_test=${expected_selector_visual_test}/" \
  | sed -E "s/^selector_visual_hold=.*/selector_visual_hold=${expected_selector_visual_hold}/" \
  | sed -E "s/^selector_logo_preinit=.*/selector_logo_preinit=${expected_selector_logo_preinit}/" \
  | sed -E "s/^selector_logo_command=.*/selector_logo_command=${expected_selector_logo_command}/" \
  | sed -E "s/^selector_logo_hold=.*/selector_logo_hold=${expected_selector_logo_hold}/" \
  | sed -E "s/^selector_diag_force_bootm=.*/selector_diag_force_bootm=${expected_selector_diag_force_bootm}/" \
  | sed -E "s/^bootlogo=.*/bootlogo=${expected_bootlogo}/" \
  | sed -E "s/^logo=.*/logo=${expected_logo}/" \
  | sed -E "s/^extlinux_first=.*/extlinux_first=${expected_extlinux_first}/" \
  | sed -E "s/^bootmenu_first=.*/bootmenu_first=${expected_bootmenu_first}/" \
  | sed -E "s/^bootmenu_timeout=.*/bootmenu_timeout=${expected_bootmenu_timeout}/" \
  | sed -E "s/^bootmenu_default=.*/bootmenu_default=${expected_bootmenu_default}/" \
  | sed -E "s/^kernel_selector_first=.*/kernel_selector_first=${expected_kernel_selector_first}/" \
  | sed -E "s/^kernel_selector_timeout=.*/kernel_selector_timeout=${expected_kernel_selector_timeout}/" \
  | sed -E "s/^bootgui_selector=.*/bootgui_selector=${expected_bootgui_selector}/" \
  | sed '/^$/d' \
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
  /boot/bootlogo.bmp
  /boot/boot.bmp
  /boot/boot1.bmp
  /boot/fastbootlogo.bmp
)
for optional_file in \
  /boot/efi/extlinux/extlinux.conf \
  /boot/efi/boot.scr \
  /boot/efi/bootlogo.bmp \
  /boot/efi/boot.bmp \
  /boot/efi/boot1.bmp \
  /boot/efi/fastbootlogo.bmp \
  /boot/grub/grub.cfg \
  /boot/uInitrd-orangepi4pro-bootselect \
  /boot/EFI/BOOT/BOOTAA64.EFI \
  /boot/EFI/BOOT/grub.cfg \
  /boot/efi/EFI/BOOT/BOOTAA64.EFI \
  /boot/efi/EFI/BOOT/grub.cfg; do
  [ -e "$optional_file" ] && hash_files+=("$optional_file")
done
sha256sum "${hash_files[@]}"

printf '\nBoot-menu asset validation passed.\n'

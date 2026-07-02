#!/usr/bin/env bash
set -euo pipefail

defconfig=${1:-/usr/lib/u-boot/sun60iw2p1_t736_defconfig}

if [ ! -r "$defconfig" ]; then
  printf 'ERROR: cannot read U-Boot defconfig: %s\n' "$defconfig" >&2
  exit 1
fi

require_set() {
  local opt=$1
  if grep -q "^CONFIG_${opt}=y$" "$defconfig"; then
    printf 'OK: CONFIG_%s=y\n' "$opt"
  else
    printf 'MISSING: CONFIG_%s is not enabled\n' "$opt"
    return 1
  fi
}

printf 'Checking U-Boot selector capabilities from %s\n\n' "$defconfig"

status=0
require_set MENU || status=1
require_set CMD_PXE || status=1
require_set DM_VIDEO || status=1

printf '\nInput requirements for deck-local boot selection:\n'
require_set USB_KEYBOARD || status=1
require_set DM_KEYBOARD || status=1

printf '\nObserved boot settings:\n'
grep -E 'CONFIG_(BOOTDELAY|BOOTCOMMAND|CONSOLE_MUX|SYS_CONSOLE_IS_IN_ENV|CMD_BOOTMENU|AUTOBOOT_MENU_SHOW|EFI_LOADER)=' "$defconfig" || true

if [ "$status" -ne 0 ]; then
  cat <<'MSG'

Result: current installed U-Boot is not sufficient for reliable HDMI plus USB
keyboard boot selection. Use bounded extlinux defaults or serial-console
selection until a keyboard-enabled U-Boot package is safely testable.
MSG
  exit 1
fi

printf '\nResult: U-Boot has the expected display/menu/input capabilities.\n'

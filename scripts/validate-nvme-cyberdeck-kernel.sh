#!/usr/bin/env bash
set -euo pipefail

base="${1:-/mnt/orangepi4pro-m2}"
krel="${2:-5.15.147-sun60iw2-cyberdeck}"
root="$base/ubuntu-root"
boot="$base/boot"
efi="$base/efi"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [ -e "$1" ] || fail "missing $1"
}

printf 'Validating NVMe cyberdeck kernel at %s for %s\n\n' "$base" "$krel"

require_file "$boot/uImage-$krel"
require_file "$boot/uInitrd-$krel"
require_file "$boot/config-$krel"
require_file "$boot/dtb-$krel/allwinner/sun60i-a733-orangepi-4-pro.dtb"
require_file "$root/lib/modules/$krel/modules.dep"

printf 'Kernel config requirements:\n'
for opt in \
  CONFIG_HID_MULTITOUCH \
  CONFIG_HIDRAW \
  CONFIG_UHID \
  CONFIG_INPUT_MISC \
  CONFIG_INPUT_UINPUT \
  CONFIG_INPUT_EVDEV \
  CONFIG_USB_HID \
  CONFIG_NVME_CORE \
  CONFIG_BLK_DEV_NVME \
  CONFIG_OVERLAY_FS; do
  grep -q "^${opt}=" "$boot/config-$krel" || fail "$opt missing from $boot/config-$krel"
  grep "^${opt}=" "$boot/config-$krel"
done

printf '\nModule metadata:\n'
sudo chroot "$root" modinfo -k "$krel" hid-multitouch uhid uinput >/tmp/orangepi4pro-modinfo.$$
grep -E '^(filename|name|vermagic):' /tmp/orangepi4pro-modinfo.$$
rm -f /tmp/orangepi4pro-modinfo.$$

printf '\nBoot files:\n'
file "$boot/uImage-$krel" "$boot/uInitrd-$krel" "$boot/boot.scr"

if [ -d "$efi" ]; then
  printf '\nBoot/EFI mirror hashes:\n'
  sha256sum "$boot/boot.scr" "$efi/boot.scr" "$boot/uImage" "$efi/uImage" "$boot/uInitrd" "$efi/uInitrd"
fi

printf '\nTarget root and boot env:\n'
grep '^rootdev=UUID=eb86cfeb-60c7-4513-bc69-f6d28e9d561b$' "$boot/orangepiEnv.txt" \
  || fail 'orangepiEnv.txt does not point at UBUNTU_ROOT UUID'
grep ' / ext4 ' "$root/etc/fstab"

printf '\nNative touch userspace:\n'
sudo chroot "$root" dpkg-query -W -f='${Package}\t${Version}\n' \
  onboard libinput-tools evtest xinput xserver-xorg-input-libinput

printf '\nValidation passed. No writes performed.\n'

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sd_root=/mnt/opisd-rw
timeout=10
artifact="$repo_root/build/uInitrd-orangepi4pro-bootselect"

usage() {
  cat <<'EOF'
Usage: sudo scripts/stage-kernel-initramfs-selector.sh [--sd-root DIR] [--timeout SECONDS]

Stages the kernel/initramfs boot selector on the NVMe boot partition and the SD
recovery root. It does not write boot sectors, partition tables, firmware, or
TOC1/U-Boot packages.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sd-root)
      sd_root=${2:-}
      shift 2
      ;;
    --timeout)
      timeout=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ "${EUID:-$(id -u)}" -eq 0 ] || fail 'run as root'
[[ "$timeout" =~ ^[0-9]+$ ]] || fail '--timeout must be an integer'
[ "$timeout" -ge 5 ] || fail '--timeout must be at least 5 seconds'
[ -d /boot ] || fail '/boot is missing'
[ -d "$sd_root/boot" ] || fail "SD boot directory missing: $sd_root/boot"

"$repo_root/scripts/build-kernel-initramfs-selector.sh" "$artifact"
"$repo_root/scripts/validate-kernel-initramfs-selector.sh" "$artifact"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_dir=/var/cache/orangepi4pro-images/boot-backups/kernel-initramfs-selector-$stamp
mkdir -p "$backup_dir/nvme" "$backup_dir/sd"
cp -a /boot/boot.cmd /boot/boot.scr /boot/orangepiEnv.txt "$backup_dir/nvme/"
cp -a "$sd_root/boot/boot.cmd" "$sd_root/boot/boot.scr" "$sd_root/boot/orangepiEnv.txt" "$backup_dir/sd/"

install -m 0644 "$artifact" /boot/uInitrd-orangepi4pro-bootselect
install -m 0644 "$artifact" "$sd_root/boot/uInitrd-orangepi4pro-bootselect"
install -m 0644 "$repo_root/configs/boot.cmd" /boot/boot.cmd
install -m 0644 "$repo_root/configs/boot.cmd" "$sd_root/boot/boot.cmd"
mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr >/dev/null
install -m 0644 /boot/boot.scr "$sd_root/boot/boot.scr"

for env in /boot/orangepiEnv.txt "$sd_root/boot/orangepiEnv.txt"; do
  grep -q '^kernel_selector_first=' "$env" \
    && sed -i 's/^kernel_selector_first=.*/kernel_selector_first=true/' "$env" \
    || printf '\nkernel_selector_first=true\n' >> "$env"
  grep -q '^kernel_selector_timeout=' "$env" \
    && sed -i "s/^kernel_selector_timeout=.*/kernel_selector_timeout=$timeout/" "$env" \
    || printf 'kernel_selector_timeout=%s\n' "$timeout" >> "$env"
  grep -q '^extlinux_first=' "$env" \
    && sed -i 's/^extlinux_first=.*/extlinux_first=false/' "$env"
  grep -q '^bootmenu_first=' "$env" \
    && sed -i 's/^bootmenu_first=.*/bootmenu_first=false/' "$env"
  grep -q '^bootgui_selector=' "$env" \
    && sed -i 's/^bootgui_selector=.*/bootgui_selector=false/' "$env"
done

rm -f /boot/orangepiBootOnce.txt "$sd_root/boot/orangepiBootOnce.txt"

for target_root in / "$sd_root"; do
  install -d -m 0755 \
    "$target_root/usr/local/sbin" \
    "$target_root/etc/systemd/system" \
    "$target_root/etc/systemd/system/multi-user.target.wants" \
    "$target_root/etc"
  install -m 0755 "$repo_root/scripts/orangepi4pro-linux-boot-selector" \
    "$target_root/usr/local/sbin/orangepi4pro-linux-boot-selector"
  install -m 0644 "$repo_root/systemd/orangepi4pro-linux-boot-selector.service" \
    "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service"
  install -m 0644 "$repo_root/configs/orangepi4pro-boot-selector.conf" \
    "$target_root/etc/orangepi4pro-boot-selector.conf"
  ln -sfn ../orangepi4pro-linux-boot-selector.service \
    "$target_root/etc/systemd/system/multi-user.target.wants/orangepi4pro-linux-boot-selector.service"
done

systemctl daemon-reload
sync

printf 'Staged kernel initramfs selector with timeout=%s seconds.\n' "$timeout"
printf 'Backups: %s\n' "$backup_dir"

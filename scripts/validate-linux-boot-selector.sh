#!/usr/bin/env bash
set -euo pipefail

target_root=${1:-/}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [ -e "$1" ] || fail "missing $1"
}

printf 'Validating Orange Pi 4 Pro Linux boot selector in %s\n\n' "$target_root"

require_file "$target_root/usr/local/sbin/orangepi4pro-linux-boot-selector"
require_file "$target_root/usr/local/bin/orangepi4pro-x11-boot-selector"
require_file "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service"
require_file "$target_root/etc/orangepi4pro-boot-selector.conf"
require_file "$target_root/etc/xdg/autostart/orangepi4pro-x11-boot-selector.desktop"
require_file "$target_root/etc/sudoers.d/orangepi4pro-boot-selector"
require_file "$target_root/etc/systemd/system/multi-user.target.wants/orangepi4pro-linux-boot-selector.service"

grep -q '^Before=display-manager.service$' \
  "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service" \
  || fail 'selector cleanup service must run before display-manager'
grep -q '^ExecStart=/usr/local/sbin/orangepi4pro-linux-boot-selector --clear$' \
  "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service" \
  || fail 'selector systemd service must only clear stale bootonce files'
grep -q '^Exec=/usr/local/bin/orangepi4pro-x11-boot-selector$' \
  "$target_root/etc/xdg/autostart/orangepi4pro-x11-boot-selector.desktop" \
  || fail 'X11 selector autostart entry missing'
grep -q '^SELECTOR_ENABLED=true$' "$target_root/etc/orangepi4pro-boot-selector.conf" \
  || fail 'selector config should enable the selector'
grep -q '^X11_SELECTOR_ENABLED=true$' "$target_root/etc/orangepi4pro-boot-selector.conf" \
  || fail 'X11 selector config should enable the visible selector'
grep -q '^BOOTONCE_RELATIVE_PATH=boot/orangepiBootOnce.txt$' \
  "$target_root/etc/orangepi4pro-boot-selector.conf" \
  || fail 'selector config should use the boot script bootonce path'
grep -q 'NOPASSWD: /usr/local/sbin/orangepi4pro-linux-boot-selector --boot-sd' \
  "$target_root/etc/sudoers.d/orangepi4pro-boot-selector" \
  || fail 'sudoers rule must be scoped to the SD boot request helper'

bash -n "$target_root/usr/local/sbin/orangepi4pro-linux-boot-selector"
python3 -m py_compile "$target_root/usr/local/bin/orangepi4pro-x11-boot-selector"

if [ "$target_root" = "/" ]; then
  /usr/local/sbin/orangepi4pro-linux-boot-selector --validate
  systemctl cat orangepi4pro-linux-boot-selector.service >/dev/null
  visudo -cf /etc/sudoers.d/orangepi4pro-boot-selector >/dev/null
fi

printf 'Linux boot selector validation passed.\n'

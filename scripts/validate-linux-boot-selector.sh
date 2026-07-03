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
require_file "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service"
require_file "$target_root/etc/orangepi4pro-boot-selector.conf"
require_file "$target_root/etc/systemd/system/multi-user.target.wants/orangepi4pro-linux-boot-selector.service"

grep -q '^Before=display-manager.service getty@tty1.service$' \
  "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service" \
  || fail 'selector service must run before display-manager and tty1 getty'
grep -q '^TTYPath=/dev/tty1$' \
  "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service" \
  || fail 'selector service must bind tty1'
grep -q '^SELECTOR_ENABLED=true$' "$target_root/etc/orangepi4pro-boot-selector.conf" \
  || fail 'selector config should enable the selector'
grep -q '^BOOTONCE_RELATIVE_PATH=boot/orangepiBootOnce.txt$' \
  "$target_root/etc/orangepi4pro-boot-selector.conf" \
  || fail 'selector config should use the boot script bootonce path'

bash -n "$target_root/usr/local/sbin/orangepi4pro-linux-boot-selector"

if [ "$target_root" = "/" ]; then
  /usr/local/sbin/orangepi4pro-linux-boot-selector --validate
  systemctl cat orangepi4pro-linux-boot-selector.service >/dev/null
fi

printf 'Linux boot selector validation passed.\n'

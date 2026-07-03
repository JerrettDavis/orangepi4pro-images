#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target_root=/
enable_service=true

usage() {
  cat <<'EOF'
Usage: sudo scripts/install-linux-boot-selector.sh [--target-root PATH] [--no-enable]

Installs the early Linux tty boot selector into a mounted root filesystem.
This writes only normal files under the target root; it does not alter boot
sectors, partition tables, U-Boot environment sectors, or firmware.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-root)
      target_root=${2:?missing value for --target-root}
      shift 2
      ;;
    --no-enable)
      enable_service=false
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'ERROR: rerun with sudo so system files can be written\n' >&2
  exit 1
fi

if [ ! -d "$target_root" ]; then
  printf 'ERROR: target root does not exist: %s\n' "$target_root" >&2
  exit 1
fi

install -d -m 0755 \
  "$target_root/usr/local/bin" \
  "$target_root/usr/local/sbin" \
  "$target_root/etc/xdg/autostart" \
  "$target_root/etc/systemd/system" \
  "$target_root/etc/systemd/system/multi-user.target.wants" \
  "$target_root/etc/sudoers.d" \
  "$target_root/etc"

install -m 0755 "$repo_root/scripts/orangepi4pro-linux-boot-selector" \
  "$target_root/usr/local/sbin/orangepi4pro-linux-boot-selector"
install -m 0755 "$repo_root/scripts/orangepi4pro-x11-boot-selector" \
  "$target_root/usr/local/bin/orangepi4pro-x11-boot-selector"
install -m 0644 "$repo_root/systemd/orangepi4pro-linux-boot-selector.service" \
  "$target_root/etc/systemd/system/orangepi4pro-linux-boot-selector.service"
install -m 0644 "$repo_root/configs/orangepi4pro-boot-selector.conf" \
  "$target_root/etc/orangepi4pro-boot-selector.conf"
install -m 0644 "$repo_root/configs/orangepi4pro-x11-boot-selector.desktop" \
  "$target_root/etc/xdg/autostart/orangepi4pro-x11-boot-selector.desktop"
install -m 0440 "$repo_root/configs/orangepi4pro-boot-selector.sudoers" \
  "$target_root/etc/sudoers.d/orangepi4pro-boot-selector"

if command -v visudo >/dev/null 2>&1 && [ "$target_root" = "/" ]; then
  visudo -cf "$target_root/etc/sudoers.d/orangepi4pro-boot-selector"
fi

if [ "$enable_service" = true ]; then
  ln -sfn ../orangepi4pro-linux-boot-selector.service \
    "$target_root/etc/systemd/system/multi-user.target.wants/orangepi4pro-linux-boot-selector.service"
fi

if [ "$target_root" = "/" ]; then
  systemctl daemon-reload
  if [ "$enable_service" = true ]; then
    systemctl enable orangepi4pro-linux-boot-selector.service
  fi
fi

printf 'Installed Linux boot selector into %s\n' "$target_root"

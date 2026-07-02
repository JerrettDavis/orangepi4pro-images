#!/usr/bin/env bash
set -euo pipefail

base="${1:-/mnt/orangepi4pro-m2}"

require_label() {
  local label=$1
  if [ ! -e "/dev/disk/by-label/$label" ]; then
    printf 'ERROR: missing filesystem label %s\n' "$label" >&2
    exit 1
  fi
}

mount_label() {
  local label=$1
  local path=$2
  require_label "$label"
  sudo mkdir -p "$path"
  if findmnt -M "$path" >/dev/null 2>&1; then
    printf '[SKIP] %s already mounted at %s\n' "$label" "$path"
  else
    sudo mount "/dev/disk/by-label/$label" "$path"
    printf '[OK] mounted %s at %s\n' "$label" "$path"
  fi
}

mount_label OPI_EFI "$base/efi"
mount_label OPI_BOOT "$base/boot"
mount_label UBUNTU_ROOT "$base/ubuntu-root"
mount_label KALI_ROOT "$base/kali-root"
mount_label TOOLS "$base/tools"
mount_label HOME "$base/home"
mount_label RESCUE_OR_ARCH "$base/rescue-or-arch"
mount_label IMAGES_CACHE "$base/images-cache"

sudo chown orangepi:orangepi "$base/tools" "$base/home" "$base/images-cache"

lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,PARTLABEL,MOUNTPOINTS /dev/nvme0n1


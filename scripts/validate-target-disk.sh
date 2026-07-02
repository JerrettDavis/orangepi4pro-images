#!/usr/bin/env bash
set -euo pipefail

disk="${1:-/dev/nvme0n1}"

if [ ! -b "$disk" ]; then
  printf 'ERROR: %s is not a block device\n' "$disk" >&2
  exit 1
fi

model="$(lsblk -dn -o MODEL "$disk" | sed 's/[[:space:]]*$//')"
serial="$(lsblk -dn -o SERIAL "$disk" | sed 's/[[:space:]]*$//')"
size="$(lsblk -dn -o SIZE "$disk" | sed 's/[[:space:]]*$//')"

printf 'Target disk: %s\nModel: %s\nSerial: %s\nSize: %s\n\n' "$disk" "$model" "$serial" "$size"

if [ "$disk" != "/dev/nvme0n1" ]; then
  printf 'ERROR: expected /dev/nvme0n1 for this project, got %s\n' "$disk" >&2
  exit 1
fi

case "$model" in
  *"Fanxiang S500Pro 256GB"*) ;;
  *)
    printf 'ERROR: unexpected model: %s\n' "$model" >&2
    exit 1
    ;;
esac

if lsblk -nr -o MOUNTPOINT "$disk" | grep -q .; then
  printf 'ERROR: %s or one of its partitions is mounted\n' "$disk" >&2
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$disk"
  exit 1
fi

printf 'Target disk validation passed. No writes performed.\n'


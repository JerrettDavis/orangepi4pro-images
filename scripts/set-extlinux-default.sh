#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Set or preview the default extlinux boot entry.

Usage:
  scripts/set-extlinux-default.sh [--apply] <label>
  scripts/set-extlinux-default.sh --list

Labels currently used by this project:
  ubuntu-nvme
  ubuntu-sd
  ubuntu-nvme-verbose

Without --apply, this script validates and prints the change it would make.
With --apply, it updates /boot/extlinux/extlinux.conf and mirrors the file to
/boot/efi/extlinux/extlinux.conf. If the SD boot source is mounted at
/mnt/opisd-ro, it is updated too.
USAGE
}

apply=false
list=false
label=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      apply=true
      ;;
    --list)
      list=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$label" ]; then
        printf 'ERROR: only one label can be provided\n' >&2
        usage >&2
        exit 2
      fi
      label=$1
      ;;
  esac
  shift
done

conf=/boot/extlinux/extlinux.conf
efi_conf=/boot/efi/extlinux/extlinux.conf
sd_conf=/mnt/opisd-ro/boot/extlinux/extlinux.conf

if [ ! -r "$conf" ]; then
  printf 'ERROR: cannot read %s\n' "$conf" >&2
  exit 1
fi

labels=$(awk '/^LABEL[[:space:]]+/ { print $2 }' "$conf")

if [ "$list" = true ]; then
  printf '%s\n' "$labels"
  exit 0
fi

if [ -z "$label" ]; then
  printf 'ERROR: missing label\n' >&2
  usage >&2
  exit 2
fi

if ! printf '%s\n' "$labels" | grep -Fxq "$label"; then
  printf 'ERROR: label not found in %s: %s\n' "$conf" "$label" >&2
  printf 'Available labels:\n' >&2
  while IFS= read -r available_label; do
    printf '  %s\n' "$available_label" >&2
  done <<< "$labels"
  exit 1
fi

current=$(awk '/^DEFAULT[[:space:]]+/ { print $2; exit }' "$conf")
printf 'Current extlinux default: %s\n' "${current:-<unset>}"
printf 'Requested extlinux default: %s\n' "$label"

if [ "$apply" != true ]; then
  printf 'Dry run only. Re-run with --apply to update boot files.\n'
  exit 0
fi

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'ERROR: --apply requires sudo/root\n' >&2
  exit 1
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p /boot/backups/default-selector-"$stamp"
cp -a "$conf" /boot/backups/default-selector-"$stamp"/extlinux.conf

sed -i "s/^DEFAULT[[:space:]].*/DEFAULT $label/" "$conf"

mkdir -p "$(dirname "$efi_conf")"
cp -a "$conf" "$efi_conf"

if mountpoint -q /mnt/opisd-ro && [ -e "$sd_conf" ]; then
  if ! [ -w "$sd_conf" ]; then
    mount -o remount,rw /mnt/opisd-ro || true
  fi
  if [ -w "$sd_conf" ]; then
    cp -a "$conf" "$sd_conf"
    mount -o remount,ro /mnt/opisd-ro || true
  else
    printf 'WARNING: SD boot source mounted but not writable; skipped %s\n' "$sd_conf" >&2
  fi
fi

sync
printf 'Updated extlinux default to %s\n' "$label"

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
disk=/dev/nvme0n1
base=/mnt/orangepi4pro-m2
write=false
sd_boot_dir=/boot
old_nvme_root_uuid=eb86cfeb-60c7-4513-bc69-f6d28e9d561b

usage() {
  cat <<'USAGE'
Reimage an Orange Pi 4 Pro NVMe from the booted SD recovery system.

Usage:
  scripts/reimage-nvme-from-sd.sh [--disk /dev/nvme0n1] [--mount-base DIR] [--sd-boot-dir /boot] [--yes]

Default mode is a dry run. With --yes and ORANGEPI4PRO_REIMAGE_NVME=1, this
script repartitions and formats the target NVMe, clones the running SD root to
UBUNTU_ROOT, installs current boot assets, patches boot UUIDs for the new disk,
and leaves the SD boot files able to boot the rebuilt NVMe.

It never writes SPI/MTD. It refuses write mode unless the current root is on an
SD/MMC device and no target NVMe partition is mounted.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

run() {
  printf '+ %s\n' "$*"
  "$@"
}

part_path() {
  local n=$1
  case "$disk" in
    *[0-9]) printf '%sp%s\n' "$disk" "$n" ;;
    *) printf '%s%s\n' "$disk" "$n" ;;
  esac
}

root_source_disk() {
  local source
  source=$(findmnt -n -o SOURCE /)
  lsblk -no PKNAME "$source" 2>/dev/null | head -1
}

require_cmds() {
  local cmd
  for cmd in sfdisk partprobe udevadm mkfs.vfat mkfs.ext4 rsync mkimage blkid findmnt lsblk sed; do
    command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
  done
}

validate_target() {
  [ -b "$disk" ] || fail "target is not a block device: $disk"
  [ "$(lsblk -dn -o TYPE "$disk")" = disk ] || fail "target is not a whole disk: $disk"
  case "$disk" in
    /dev/nvme*n*) ;;
    *) fail "target must be an NVMe namespace, got $disk" ;;
  esac
  if lsblk -nr -o MOUNTPOINTS "$disk" | grep -q .; then
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,PARTLABEL,MOUNTPOINTS "$disk" >&2
    fail "$disk or one of its partitions is mounted"
  fi
}

validate_write_context() {
  [ "${ORANGEPI4PRO_REIMAGE_NVME:-}" = 1 ] \
    || fail 'refusing write without ORANGEPI4PRO_REIMAGE_NVME=1'
  [ "${EUID:-$(id -u)}" -eq 0 ] || fail 'rerun with sudo for write mode'
  case "$(root_source_disk)" in
    mmcblk*|sd*) ;;
    *)
      findmnt /
      fail 'write mode must be run from SD/MMC recovery root, not the current root device'
      ;;
  esac
}

partition_disk() {
  sfdisk "$disk" <<'EOF'
label: gpt
unit: MiB
start=1, size=512, type=uefi, name="OPI_EFI"
size=2048, type=linux, name="OPI_BOOT"
size=51200, type=linux, name="UBUNTU_ROOT"
size=46080, type=linux, name="KALI_ROOT"
size=24576, type=linux, name="TOOLS"
size=32768, type=linux, name="HOME"
size=32768, type=linux, name="RESCUE_OR_ARCH"
type=linux, name="IMAGES_CACHE"
EOF
  partprobe "$disk"
  udevadm settle
}

format_partitions() {
  mkfs.vfat -F 32 -n OPI_EFI "$(part_path 1)"
  mkfs.ext4 -F -L OPI_BOOT "$(part_path 2)"
  mkfs.ext4 -F -L UBUNTU_ROOT "$(part_path 3)"
  mkfs.ext4 -F -L KALI_ROOT "$(part_path 4)"
  mkfs.ext4 -F -L TOOLS "$(part_path 5)"
  mkfs.ext4 -F -L HOME "$(part_path 6)"
  mkfs.ext4 -F -L RESCUE_OR_ARCH "$(part_path 7)"
  mkfs.ext4 -F -L IMAGES_CACHE "$(part_path 8)"
}

clone_sd_root() {
  local root="$base/ubuntu-root"
  mkdir -p "$root"
  rsync -aAXH --numeric-ids --delete \
    --exclude=/dev/* \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/tmp/* \
    --exclude=/run/* \
    --exclude=/mnt/* \
    --exclude=/media/* \
    --exclude=/lost+found \
    / "$root"/
  mkdir -p "$root"/{dev,proc,sys,tmp,run,mnt,media,boot,boot/efi}
  chmod 1777 "$root/tmp"
}

patch_boot_tree() {
  local boot_dir=$1
  local root_uuid=$2
  local stamp
  stamp=$(date -u +%Y%m%dT%H%M%SZ)

  [ -d "$boot_dir" ] || return 0
  mkdir -p "$boot_dir/backups/pre-reimage-uuid-patch-$stamp"
  for file in boot.cmd boot.scr orangepiEnv.txt extlinux/extlinux.conf; do
    [ -e "$boot_dir/$file" ] \
      && cp -a "$boot_dir/$file" "$boot_dir/backups/pre-reimage-uuid-patch-$stamp/${file//\//-}"
  done

  for file in boot.cmd orangepiEnv.txt extlinux/extlinux.conf; do
    [ -f "$boot_dir/$file" ] || continue
    sed -i \
      -e "s/$old_nvme_root_uuid/$root_uuid/g" \
      -e "s#^rootdev=.*#rootdev=UUID=$root_uuid#" \
      "$boot_dir/$file"
  done
  [ -f "$boot_dir/boot.cmd" ] \
    && mkimage -C none -A arm -T script -d "$boot_dir/boot.cmd" "$boot_dir/boot.scr"
}

print_plan() {
  cat <<EOF
dry_run=true
target_disk=$disk
mount_base=$base
sd_boot_dir=$sd_boot_dir
root_source=$(findmnt -n -o SOURCE /)

Planned destructive write-mode steps:
1. Validate $disk is an unmounted NVMe namespace.
2. Recreate GPT partitions: OPI_EFI, OPI_BOOT, UBUNTU_ROOT, KALI_ROOT,
   TOOLS, HOME, RESCUE_OR_ARCH, IMAGES_CACHE.
3. Format p1 as FAT32 and p2-p8 as ext4 with the expected labels.
4. Mount the layout under $base.
5. Clone the running SD root into $base/ubuntu-root with rsync.
6. Install and patch boot assets in OPI_BOOT, OPI_EFI, and SD /boot so the
   new UBUNTU_ROOT UUID is used.

No writes were performed. To execute from SD recovery:
  sudo ORANGEPI4PRO_REIMAGE_NVME=1 $0 --yes
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)
      disk=${2:-}
      shift
      ;;
    --mount-base)
      base=${2:-}
      shift
      ;;
    --sd-boot-dir)
      sd_boot_dir=${2:-}
      shift
      ;;
    --yes)
      write=true
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
  shift
done

[ -n "$disk" ] || fail '--disk cannot be empty'
[ -n "$base" ] || fail '--mount-base cannot be empty'
[ -n "$sd_boot_dir" ] || fail '--sd-boot-dir cannot be empty'

if [ "$write" != true ]; then
  print_plan
  exit 0
fi

require_cmds
validate_write_context
validate_target

run partition_disk
run format_partitions
run "$repo_root/scripts/mount-nvme-layout.sh" "$base"
run clone_sd_root
run "$repo_root/scripts/prepare-live-clone-boot-assets.sh" "$base"
run "$repo_root/scripts/install-extlinux-selector.sh" "$base/boot" "$base/efi"

root_uuid=$(blkid -s UUID -o value /dev/disk/by-label/UBUNTU_ROOT)
patch_boot_tree "$base/boot" "$root_uuid"
patch_boot_tree "$base/efi" "$root_uuid"
patch_boot_tree "$sd_boot_dir" "$root_uuid"

sync
printf 'NVMe reimage completed for %s with UBUNTU_ROOT UUID %s\n' "$disk" "$root_uuid"

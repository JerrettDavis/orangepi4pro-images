#!/usr/bin/env bash
set -euo pipefail

disk="${1:-/dev/nvme0n1}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/validate-target-disk.sh" "$disk"

cat <<'PLAN'

DRY RUN: proposed GPT partition table only.

label: gpt
unit: MiB

OPI_EFI       512 MiB  FAT32
OPI_BOOT     2048 MiB ext4
UBUNTU_ROOT 51200 MiB ext4
KALI_ROOT   46080 MiB ext4
TOOLS       24576 MiB ext4
HOME        32768 MiB ext4
RESCUE_OR_ARCH 32768 MiB ext4
IMAGES_CACHE remaining ext4 or btrfs

Future reviewed command shape:

sfdisk /dev/nvme0n1 <<'EOF'
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

No writes were performed.
PLAN


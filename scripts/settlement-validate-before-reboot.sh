#!/usr/bin/env bash
set -euo pipefail

images_repo=/home/orangepi/orangepi4pro-images
board_repo=/home/orangepi/orangepi4pro-board-support
package=/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst-hdmi-phandles.fex
device=/dev/mmcblk1
sd_mount=/mnt/opisd-ro
expected_bootchooser=extlinux-legacy-nvme
seek_blocks=2050
block_size=8192
write_log=false
log_dir=/var/cache/orangepi4pro-images/settlement

usage() {
  cat <<'USAGE'
Validate that the Orange Pi 4 Pro boot state is settled before reboot.

Usage:
  scripts/settlement-validate-before-reboot.sh [options]

Options:
  --images-repo DIR          images repo path
  --board-repo DIR           board-support repo path
  --package FILE             expected installed SD TOC1 package
  --device DEV               SD card block device, default /dev/mmcblk1
  --sd-mount DIR             mounted SD root for active-source checks
  --expected-bootchooser ID  expected /proc/cmdline bootchooser marker
  --write-log                also write a timestamped report under /var/cache
  -h, --help                 show this help

The validator is intentionally strict. It fails unless both repos are clean and
pushed to their upstreams, live boot-menu assets match the expected NVMe-primary
test state, and the SD bootloader package slot byte-matches --package.
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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --images-repo)
      images_repo=${2:-}
      shift
      ;;
    --board-repo)
      board_repo=${2:-}
      shift
      ;;
    --package)
      package=${2:-}
      shift
      ;;
    --device)
      device=${2:-}
      shift
      ;;
    --sd-mount)
      sd_mount=${2:-}
      shift
      ;;
    --expected-bootchooser)
      expected_bootchooser=${2:-}
      shift
      ;;
    --write-log)
      write_log=true
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

[ -n "$images_repo" ] || fail '--images-repo cannot be empty'
[ -n "$board_repo" ] || fail '--board-repo cannot be empty'
[ -n "$package" ] || fail '--package cannot be empty'
[ -n "$device" ] || fail '--device cannot be empty'
[ -n "$sd_mount" ] || fail '--sd-mount cannot be empty'
[ -n "$expected_bootchooser" ] || fail '--expected-bootchooser cannot be empty'

export HOME=${HOME:-/root}

check_repo() {
  local repo=$1
  local name=$2
  local upstream
  local dirty
  local counts
  local behind
  local ahead

  [ -d "$repo/.git" ] || fail "$name is not a git repo: $repo"
  git config --global --add safe.directory "$repo" >/dev/null 2>&1 || true

  dirty=$(git -C "$repo" status --porcelain=v1)
  if [ -n "$dirty" ]; then
    printf '%s\n' "$dirty" >&2
    fail "$name has uncommitted changes"
  fi

  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) \
    || fail "$name has no upstream branch"
  counts=$(git -C "$repo" rev-list --left-right --count "$upstream"...HEAD)
  behind=${counts%%[[:space:]]*}
  ahead=${counts##*[[:space:]]}
  [ "$behind" = 0 ] || fail "$name is behind $upstream by $behind commit(s)"
  [ "$ahead" = 0 ] || fail "$name has $ahead unpushed commit(s) relative to $upstream"

  printf '%s clean and pushed: %s @ %s\n' \
    "$name" \
    "$upstream" \
    "$(git -C "$repo" rev-parse --short HEAD)"
}

readback_package() {
  local package_size
  local package_sha
  local verify_blocks
  local verify_path

  [ -f "$package" ] || fail "expected package not found: $package"
  [ -b "$device" ] || fail "not a block device: $device"
  package_size=$(stat -c '%s' "$package")
  [ "$package_size" -gt 0 ] || fail "package is empty: $package"
  package_sha=$(sha256sum "$package" | awk '{print $1}')
  case "$package_sha" in
    34f52a23883a427d6471bdfc69654ef853a6f96a1f406a732acd64a35555852f)
      fail "refusing known-unsafe boot package in settlement gate: $package_sha"
      ;;
    dac4949d4e5ad3fdb8c3db0bf16811f2ce8ed4948c242ffeebe3c052d940f7a1)
      fail "refusing known-unsafe boot package in settlement gate: $package_sha"
      ;;
  esac
  verify_blocks=$(((package_size + block_size - 1) / block_size))
  verify_path=$(mktemp)
  dd if="$device" of="$verify_path" bs="$block_size" skip="$seek_blocks" count="$verify_blocks" status=none
  cmp -n "$package_size" "$package" "$verify_path"
  rm -f "$verify_path"
  printf 'SD bootloader slot byte-matches expected package.\n'
}

report() {
  printf 'Settlement validation report\n'
  printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'images_repo=%s\n' "$images_repo"
  printf 'board_repo=%s\n' "$board_repo"
  printf 'package=%s\n' "$package"
  printf 'device=%s\n' "$device"
  printf 'sd_mount=%s\n' "$sd_mount"
  printf 'expected_bootchooser=%s\n' "$expected_bootchooser"
  printf '\n'

  check_repo "$images_repo" images
  check_repo "$board_repo" board-support
  printf '\n'

  "$board_repo/scripts/sunxi-toc1-package.py" inspect "$package" >/dev/null
  printf 'Expected package hash:\n'
  sha256sum "$package"
  readback_package
  printf '\n'

  printf 'Running live boot-menu asset validation...\n'
  "$images_repo/scripts/validate-boot-menu-assets.sh"
  printf '\n'

  printf 'Running active boot-source validation...\n'
  "$images_repo/scripts/validate-active-boot-source.sh" "$sd_mount"
  printf '\n'

  grep -qw "bootchooser=${expected_bootchooser}" /proc/cmdline \
    || fail "running kernel does not have bootchooser=${expected_bootchooser}"
  printf 'Running cmdline has bootchooser=%s.\n' "$expected_bootchooser"
  printf '\nMounted filesystems:\n'
  findmnt / /boot /boot/efi "$sd_mount" /mnt/opisd-check -o TARGET,SOURCE,FSTYPE,OPTIONS --noheadings 2>/dev/null || true
  printf '\nSETTLEMENT VALIDATION PASSED. Reboot is allowed by this gate.\n'
}

if [ "$write_log" = true ]; then
  mkdir -p "$log_dir"
  log_path="$log_dir/settlement-$(date -u +%Y%m%dT%H%M%SZ).log"
  report | tee "$log_path"
  printf 'Wrote settlement log: %s\n' "$log_path"
else
  report
fi

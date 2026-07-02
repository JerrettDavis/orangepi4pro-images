#!/usr/bin/env bash
set -euo pipefail

expected=${1:-}

if [ -z "$expected" ]; then
  printf 'Usage: scripts/assert-bootchooser.sh EXPECTED_MARKER\n' >&2
  printf 'Example: scripts/assert-bootchooser.sh uboot-bootmenu-sd\n' >&2
  exit 2
fi

cmdline=$(cat /proc/cmdline)
printf 'Kernel command line:\n%s\n\n' "$cmdline"

if printf '%s\n' "$cmdline" | grep -q "bootchooser=${expected}"; then
  printf 'Bootchooser assertion passed: %s\n' "$expected"
  exit 0
fi

actual=$(printf '%s\n' "$cmdline" | tr ' ' '\n' | awk -F= '$1 == "bootchooser" { print $2; exit }')
if [ -z "$actual" ]; then
  actual='<missing>'
fi

printf 'ERROR: expected bootchooser=%s, got %s\n' "$expected" "$actual" >&2
exit 1

#!/usr/bin/env bash
set -euo pipefail

printf 'Checking shell syntax...\n'
while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find scripts -type f -name '*.sh' -print0)

if command -v shellcheck >/dev/null 2>&1; then
  printf 'Running shellcheck...\n'
  shellcheck scripts/*.sh
else
  printf 'shellcheck not installed; skipping optional shell lint\n'
fi

printf 'Checking dry-run script output...\n'
scripts/bootstrap-ubuntu.sh >/tmp/orangepi4pro-bootstrap-ubuntu.out
scripts/bootstrap-kali.sh >/tmp/orangepi4pro-bootstrap-kali.out
scripts/build-kernel.sh >/tmp/orangepi4pro-build-kernel.out
scripts/build-boot-assets.sh >/tmp/orangepi4pro-build-boot-assets.out
grep -q 'No rootfs was created' /tmp/orangepi4pro-bootstrap-ubuntu.out
grep -q 'No rootfs was created' /tmp/orangepi4pro-bootstrap-kali.out
grep -q 'No source was cloned and no kernel was built' /tmp/orangepi4pro-build-kernel.out
grep -q 'No boot assets were generated' /tmp/orangepi4pro-build-boot-assets.out
rm -f /tmp/orangepi4pro-bootstrap-ubuntu.out /tmp/orangepi4pro-bootstrap-kali.out \
  /tmp/orangepi4pro-build-kernel.out /tmp/orangepi4pro-build-boot-assets.out

printf 'Checking Linux boot selector templates...\n'
bash -n scripts/orangepi4pro-linux-boot-selector \
  scripts/install-linux-boot-selector.sh \
  scripts/validate-linux-boot-selector.sh
grep -q 'Before=display-manager.service getty@tty1.service' \
  systemd/orangepi4pro-linux-boot-selector.service
grep -q 'bootonce_target=sd' scripts/orangepi4pro-linux-boot-selector
grep -q 'orangepiBootOnce.txt' configs/boot.cmd

printf 'Checking boot-script safety guards...\n'
if grep -RInE '^[[:space:]]*sunxi_show_bmp[[:space:]]+boot[.]bmp' configs scripts docs; then
  printf 'ERROR: sunxi_show_bmp boot.bmp must not be called from boot scripts\n' >&2
  exit 1
fi

printf 'Scanning for obvious secret patterns...\n'
if grep -RInE '(BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|ghp_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}|password[[:space:]]*=|token[[:space:]]*=|secret[[:space:]]*=)' \
  --exclude-dir=.git .; then
  printf 'ERROR: possible secret pattern found\n' >&2
  exit 1
fi

printf 'Checking for committed binary artifacts...\n'
if find . -type f -not -path './.git/*' -exec file {} + | grep -E 'ELF|PE32 executable|Mach-O|ISO 9660|filesystem data'; then
  printf 'ERROR: binary artifact found\n' >&2
  exit 1
fi

printf 'CI checks passed.\n'

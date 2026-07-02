#!/usr/bin/env bash
set -euo pipefail

release="${1:-kali-rolling}"
target="${2:-rootfs/kali-rolling-arm64}"
mirror="${KALI_MIRROR:-http://http.kali.org/kali}"

cat <<EOF
DRY RUN: Kali arm64 rootfs bootstrap plan.

Release: $release
Target:  $target
Mirror:  $mirror

Future reviewed command shape:

sudo mmdebstrap --architectures=arm64 \\
  --variant=apt \\
  --components=main,contrib,non-free,non-free-firmware \\
  --include=systemd-sysv,ca-certificates,netbase,iproute2,isc-dhcp-client,openssh-server,sudo,kali-archive-keyring \\
  "$release" "$target" "$mirror"

No rootfs was created.
EOF


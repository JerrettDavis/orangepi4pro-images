#!/usr/bin/env bash
set -euo pipefail

release="${1:-noble}"
target="${2:-rootfs/ubuntu-$release-arm64}"
mirror="${UBUNTU_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"

cat <<EOF
DRY RUN: Ubuntu arm64 rootfs bootstrap plan.

Release: $release
Target:  $target
Mirror:  $mirror

Future reviewed command shape:

sudo mmdebstrap --architectures=arm64 \\
  --variant=minbase \\
  --components=main,restricted,universe,multiverse \\
  --include=systemd-sysv,linux-base,ca-certificates,netbase,iproute2,isc-dhcp-client,openssh-server,sudo,locales \\
  "$release" "$target" "$mirror"

No rootfs was created.
EOF


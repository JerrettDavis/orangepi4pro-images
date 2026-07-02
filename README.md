# Orange Pi 4 Pro Images

Dry-run image and rootfs assembly scripts for Ubuntu and Kali on the Allwinner
A733 / sun60iw2 Orange Pi 4 Pro.

This repo records the now-working NVMe primary baseline. Most scripts remain
dry-run by default; scripts that write to a mounted target must be explicit
about the target path and preconditions.

## Goals

- Build Ubuntu and Kali arm64 rootfs trees from official distro repositories.
- Generate boot assets compatible with stock/vendor U-Boot first.
- Keep GRUB/EFI output experimental.
- Generate a conservative M.2 partition plan without writing it.
- Add Yocto/OpenEmbedded after the vendor 5.15 NVMe boot path is confirmed,
  with board support consumed from `orangepi4pro-board-support`.

## Current Baseline

- Root: `UBUNTU_ROOT` on `/dev/nvme0n1p3`
- Boot: `OPI_BOOT` on `/dev/nvme0n1p2`
- EFI/fallback assets: `OPI_EFI` on `/dev/nvme0n1p1`
- Kernel: `5.15.147-sun60iw2-cyberdeck`
- Boot flow: vendor legacy U-Boot `bootm` with `uImage`, `uInitrd`, and DTB

## Validation

Run before pushing:

```bash
scripts/ci-checks.sh
scripts/validate-nvme-cyberdeck-kernel.sh /
```

## Releases

Push a `v*` tag after CI passes to publish a GitHub release containing a source
archive. Disk images and rootfs archives are intentionally excluded until the
image build process is reproducible end to end.

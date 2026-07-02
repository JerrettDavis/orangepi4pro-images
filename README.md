# Orange Pi 4 Pro Images

Dry-run image and rootfs assembly scripts for Ubuntu and Kali on the Allwinner
A733 / sun60iw2 Orange Pi 4 Pro.

This repo does not install to `/dev/nvme0n1` by default. Scripts print planned
actions unless a future reviewed session enables explicit execution.

## Goals

- Build Ubuntu and Kali arm64 rootfs trees from official distro repositories.
- Generate boot assets compatible with stock/vendor U-Boot first.
- Keep GRUB/EFI output experimental.
- Generate a conservative M.2 partition plan without writing it.


# Orange Pi 4 Pro Images

Dry-run image and rootfs assembly scripts for Ubuntu and Kali on the Allwinner
A733 / sun60iw2 Orange Pi 4 Pro.

This repo records the now-working NVMe primary baseline. Most scripts remain
dry-run by default; scripts that write to a mounted target must be explicit
about the target path and preconditions.

## Goals

- Build Ubuntu and Kali arm64 rootfs trees from official distro repositories.
- Generate boot assets compatible with stock/vendor U-Boot first.
- Track the current safe boot-selection boundary in
  `docs/boot-selection-plan.md`.
- Keep GRUB/EFI output experimental.
- Generate a conservative M.2 partition plan without writing it.
- Add Yocto/OpenEmbedded after the vendor 5.15 NVMe boot path is confirmed,
  with board support consumed from `orangepi4pro-board-support`.

## Current Baseline

- Root: `UBUNTU_ROOT` on `/dev/nvme0n1p3`
- Boot: `OPI_BOOT` on `/dev/nvme0n1p2`
- EFI/fallback assets: `OPI_EFI` on `/dev/nvme0n1p1`
- Kernel: `5.15.147-sun60iw2-cyberdeck`
- Boot flow: vendor U-Boot tries GRUB EFI, then extlinux, then legacy `bootm`
  fallback
- Confirmed visible selector target: X11 selector at XFCE session start.
  U-Boot visual diagnostics and tty prompts execute but are not visible on the
  deck panel before X initializes display output.
- While the SD card is inserted, vendor U-Boot still loads the active
  `boot.scr` from SD, then mounts the NVMe root via `rootdev`.

The current text boot templates are committed under `configs/`. To reinstall
them onto the mounted NVMe boot partitions and an explicitly mounted SD boot
source:

```bash
sudo scripts/install-extlinux-selector.sh /boot /boot/efi /mnt/opisd-ro/boot
```

Install the Linux selector into the current root, and into the mounted SD root
if the SD card is present:

```bash
sudo scripts/install-linux-boot-selector.sh
sudo scripts/install-linux-boot-selector.sh --target-root /mnt/opisd-ro
```

The systemd unit clears stale one-shot boot files before LightDM. The visible
prompt is launched by `/etc/xdg/autostart/orangepi4pro-x11-boot-selector.desktop`
after XFCE starts.

## Validation

Run before pushing:

```bash
scripts/ci-checks.sh
scripts/validate-nvme-cyberdeck-kernel.sh /
scripts/validate-boot-menu-assets.sh
scripts/validate-linux-boot-selector.sh /
scripts/validate-active-boot-source.sh /mnt/opisd-ro
```

## Releases

Push a `v*` tag after CI passes to publish a GitHub release containing a source
archive. Disk images and rootfs archives are intentionally excluded until the
image build process is reproducible end to end.

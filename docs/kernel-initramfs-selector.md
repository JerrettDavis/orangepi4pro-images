# Kernel Initramfs Boot Selector

The A733 Orange Pi 4 Pro vendor U-Boot currently executes boot choices, but the
HDMI display is not visible before Linux initializes DRM. The kernel initramfs
selector is a bounded fallback that runs before mounting a real Ubuntu root.

It is not a desktop or X11 selector. U-Boot loads the current cyberdeck kernel
with `uInitrd-orangepi4pro-bootselect`; the initramfs displays a high-contrast
tty1 menu, writes `orangepiBootOnce.txt` to both boot locations, syncs, and
reboots. The next U-Boot pass consumes the existing boot-script target path and
boots either NVMe Ubuntu or SD recovery Ubuntu.

Default repository state keeps this disabled:

```text
kernel_selector_first=false
```

Build and validate without staging:

```sh
scripts/build-kernel-initramfs-selector.sh build/uInitrd-orangepi4pro-bootselect
scripts/validate-kernel-initramfs-selector.sh build/uInitrd-orangepi4pro-bootselect
```

Stage for the next reboot. The staged extlinux `ubuntu-nvme` entry loads the
visible selector; the direct NVMe entry remains available as
`ubuntu-nvme-direct`.

```sh
sudo scripts/stage-kernel-initramfs-selector.sh --timeout 10
sudo scripts/settlement-validate-before-reboot.sh --expected-bootchooser boot-script-default-nvme
```

The staging script writes only normal files on `/boot`, `/boot/efi`, and the
mounted SD root:

- `uInitrd-orangepi4pro-bootselect`
- `boot.cmd`
- `boot.scr`
- `orangepiEnv.txt`
- versioned `uImage`, `uInitrd`, and DTB files needed when U-Boot sources the
  EFI partition copy first
- the clear-only `orangepi4pro-linux-boot-selector.service` cleanup unit

It does not write boot sectors, U-Boot TOC1 packages, partition tables, or
firmware. Backups are written under
`/var/cache/orangepi4pro-images/boot-backups/`.

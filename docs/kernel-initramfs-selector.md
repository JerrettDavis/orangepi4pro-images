# Kernel Initramfs Boot Selector

The A733 Orange Pi 4 Pro vendor U-Boot currently executes boot choices, but the
HDMI display is not visible before Linux initializes DRM. The kernel initramfs
selector is a bounded fallback that runs before mounting a real Ubuntu root.

It is not a desktop or X11 selector. U-Boot loads the current cyberdeck kernel
with `uInitrd-orangepi4pro-bootselect`; the initramfs first tries a small
DRM/KMS selector that explicitly modesets `/dev/dri/card0` to the
Linux-proven `1024x600` HDMI mode and draws a high-contrast menu into a dumb
scanout buffer. This avoids the observed failure where fbcon writes completed
while the panel was still black. If KMS is unavailable or mode setting fails,
the initramfs falls back to the older tty/direct-fb menu.

Selections:

- `N`, Enter on the default item, or timeout: continue into NVMe Ubuntu.
- `S`: set extlinux `DEFAULT ubuntu-sd` on the boot copies and reboot once.
  The clear-only cleanup unit restores `DEFAULT ubuntu-nvme` after the selected
  OS boots.
- `R`: reboot without changing the selected OS.

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
sudo scripts/stage-kernel-initramfs-selector.sh --timeout 30
sudo scripts/settlement-validate-before-reboot.sh --expected-bootchooser boot-script-default-nvme
```

The staging script writes only normal files on `/boot`, `/boot/efi`, and the
mounted SD root:

- `uInitrd-orangepi4pro-bootselect`
- DRM/KMS selector inside the selector initramfs, used before the tty/fb
  fallback
- direct `/dev/fb0` painter inside the selector initramfs, used as a visible
  fallback if tty text is not routed cleanly
- `boot.cmd`
- `boot.scr`
- `orangepiEnv.txt`
- versioned `uImage`, `uInitrd`, and DTB files needed when U-Boot sources the
  EFI partition copy first
- `bootselect-last.txt` evidence files after the selector runs
- the clear-only `orangepi4pro-linux-boot-selector.service` cleanup unit

It does not write boot sectors, U-Boot TOC1 packages, partition tables, or
firmware. Backups are written under
`/var/cache/orangepi4pro-images/boot-backups/`.

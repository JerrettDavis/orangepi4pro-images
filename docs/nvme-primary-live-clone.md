# NVMe Primary Live Clone

Prepared on 2026-07-02 from the running Orange Pi Ubuntu Jammy SD system.

## What Was Done

- Cloned the live SD root filesystem into `UBUNTU_ROOT`:
  `/mnt/orangepi4pro-m2/ubuntu-root`
- Preserved permissions, ownership, ACLs, xattrs, and hardlinks with `rsync`.
- Excluded pseudo-filesystems and external mount trees:
  `/dev`, `/proc`, `/sys`, `/tmp`, `/run`, `/mnt`, `/media`, `/lost+found`.
- Created target runtime and mountpoint directories.
- Wrote target `/etc/fstab` for the NVMe layout.
- Copied current vendor legacy boot assets to `OPI_BOOT`.
- Rebuilt `OPI_BOOT/boot.scr` from `boot.cmd`.
- Mirrored boot-critical fallback assets to `OPI_EFI` with symlinks
  dereferenced for FAT32.

## Target Root

- Root partition: `UBUNTU_ROOT`
- Root UUID: `eb86cfeb-60c7-4513-bc69-f6d28e9d561b`
- Current usage after clone: 9.6G used, 37G free

Target `/etc/fstab`:

```fstab
UUID=eb86cfeb-60c7-4513-bc69-f6d28e9d561b / ext4 defaults,noatime,errors=remount-ro 0 1
UUID=fa64dd02-6cd1-4d70-9d1d-88bdbdc3333b /boot ext4 defaults,noatime 0 2
UUID=C923-6E30 /boot/efi vfat defaults,noatime,umask=0077 0 2
UUID=b491343e-59c0-4048-95e2-e292cdcf8c97 /opt/cyberdeck-tools ext4 defaults,noatime,nofail 0 2
UUID=7317da29-f743-4342-a297-3f0194262e8f /srv/cyberdeck-home ext4 defaults,noatime,nofail 0 2
UUID=480c30b7-1e73-483d-9759-605f29dcd82d /var/cache/orangepi4pro-images ext4 defaults,noatime,nofail 0 2
```

## Boot Assets

The current vendor boot flow uses legacy U-Boot assets:

- `boot.scr`
- `boot.cmd`
- `orangepiEnv.txt`
- `uImage`
- `uInitrd`
- `dtb/allwinner/sun60i-a733-orangepi-4-pro.dtb`

NVMe `orangepiEnv.txt` now points at the cloned root:

```text
rootdev=UUID=eb86cfeb-60c7-4513-bc69-f6d28e9d561b
rootfstype=ext4
```

`OPI_BOOT` keeps Unix symlinks and full versioned boot artifacts. `OPI_EFI` is
FAT32, so it keeps only boot-critical fallback assets with symlinks dereferenced
into real files/directories:

- `boot.cmd`
- `boot.scr`
- `orangepiEnv.txt`
- `uImage`
- `uInitrd`
- `dtb/`
- splash and first-run text assets

## Cyberdeck Kernel Added

On 2026-07-02 a patched vendor BSP kernel was built and staged on the NVMe
target:

```text
5.15.147-sun60iw2-cyberdeck
```

Source:

- Repository: `https://github.com/orangepi-xunlong/linux-orangepi.git`
- Branch: `orange-pi-5.15-sun60iw2`
- Commit: `3de7a14a69f9e1fcbfec914c972a5398f0abd6d9`

The target boot partition now has versioned assets:

```text
Image-5.15.147-sun60iw2-cyberdeck
uImage-5.15.147-sun60iw2-cyberdeck
initrd.img-5.15.147-sun60iw2-cyberdeck
uInitrd-5.15.147-sun60iw2-cyberdeck
config-5.15.147-sun60iw2-cyberdeck
System.map-5.15.147-sun60iw2-cyberdeck
dtb-5.15.147-sun60iw2-cyberdeck/
```

Current NVMe `uImage`, `uInitrd`, and `dtb` symlinks point at that release.
`boot.scr` still uses the vendor legacy `bootm` flow.

Native HID touch support is enabled through:

```text
CONFIG_HID_MULTITOUCH=m
CONFIG_HIDRAW=y
CONFIG_UHID=m
CONFIG_INPUT_UINPUT=m
```

The NVMe target loads these modules at boot from:

```text
/etc/modules-load.d/orangepi4pro-touch.conf
```

The old QDtech X11 libusb bridge is kept as a fallback but disabled in the
NVMe clone:

```text
/home/orangepi/.config/autostart/qdtech-touch-x11.desktop
```

The Xorg `evdev` touchscreen override was moved under:

```text
/etc/X11/xorg.conf.d/disabled/
```

This leaves libinput as the default handler for the native HID event device.

## Yocto Direction

Yocto should be introduced after the NVMe 5.15 boot is confirmed, not before.
The intended split is:

- `orangepi4pro-board-support`: kernel fork, DTS/DTSI, config fragments,
  firmware notes, validation.
- `orangepi4pro-images`: image assembly, rootfs policy, boot asset packaging,
  Yocto layer integration, release artifacts.
- `orangepi4pro-cyberdeck`: project-level integration, recovery checklist, user
  workflows, hardware notes.

This keeps future Ubuntu, Kali, and Yocto images consuming the same board-support
source instead of growing separate BSP copies.

## Bootloader Caveat

No bootloader sectors, SPI flash, MTD device, or SD boot area were modified.

The running kernel exposes:

```text
mtd0: 01000000 00010000 "spi0.0"
```

That 16 MiB SPI device is likely the SD-less boot path, but it has not been
read, written, or validated yet. SD-less boot now depends on the existing board
firmware/vendor U-Boot being able to scan NVMe and load one of the prepared
boot locations.

If SD-less boot fails, reinsert the SD card and inspect the serial console or
U-Boot environment before writing any firmware.

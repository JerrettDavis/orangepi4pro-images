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
- Mirrored boot assets to `OPI_EFI` with symlinks dereferenced for FAT32.

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

`OPI_BOOT` keeps Unix symlinks. `OPI_EFI` is FAT32, so its mirror was created
with symlinks dereferenced into real files/directories.

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


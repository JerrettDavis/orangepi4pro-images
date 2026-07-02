# GRUB / Extlinux Boot Menu

Prepared on 2026-07-02 from the NVMe-primary Ubuntu baseline.

## Goal

Show both currently available Ubuntu installs at boot:

- `Ubuntu NVMe - cyberdeck kernel (/dev/nvme0n1p3)`
- `Ubuntu SD - stock kernel (/dev/mmcblk1p1)`

## Current Boot Strategy

The board still uses vendor U-Boot and legacy `boot.scr`.

Boot order in `/boot/boot.cmd`:

1. Try GRUB EFI when `grub_first=true`.
2. Try U-Boot extlinux menu when `extlinux_first=true`.
3. Try direct U-Boot `booti` when `direct_booti_first=true`.
4. Fall back to the previous legacy `bootm` flow.

This keeps the known-good `uImage`/`uInitrd` path available if GRUB EFI or
extlinux/direct `booti` returns.

## GRUB EFI Status

Installed files:

- `/boot/efi/EFI/BOOT/BOOTAA64.EFI`
- `/boot/efi/EFI/orangepi/grubaa64.efi`
- `/boot/EFI/BOOT/BOOTAA64.EFI`
- `/boot/grub/grub.cfg`
- `/boot/efi/EFI/BOOT/grub.cfg`
- `/boot/EFI/BOOT/grub.cfg`

GRUB is built as `arm64-efi` because the Ubuntu GRUB package on this system
does not provide an `arm64-uboot` target.

Important caveat: strings from the vendor U-Boot boot package show `booti` and
`extlinux/sysboot`, but no clear `bootefi`. If U-Boot lacks `bootefi`, the GRUB
EFI handoff will fail and boot will continue to extlinux or legacy `bootm`.

## Extlinux Status

Installed files:

- `/boot/extlinux/extlinux.conf`
- `/boot/efi/extlinux/extlinux.conf`

The vendor U-Boot package advertises:

```text
boot_extlinux=sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}extlinux/extlinux.conf
```

That makes extlinux the most likely functional boot selector on the current
vendor bootloader.

Reboot test results:

- GRUB EFI did not boot.
- Extlinux did not boot, even after mirroring raw kernel/initrd/DTB assets onto
  `OPI_EFI` and trying `sysboot` with `fat`, `ext2`, and `any`.
- Direct `booti` with the raw cyberdeck kernel, initrd, and DTB did not boot.
- Every test fell through to the existing legacy `bootm` path.

The probes remain in `/boot/boot.cmd`, but they are disabled in
`/boot/orangepiEnv.txt`:

```text
grub_first=false
extlinux_first=false
direct_booti_first=false
```

Treat this vendor U-Boot as legacy-`bootm` only until a serial-console command
audit proves otherwise or a newer U-Boot is installed on a recoverable boot
medium.

## Entries

NVMe Ubuntu:

- Root UUID: `eb86cfeb-60c7-4513-bc69-f6d28e9d561b`
- Kernel: `/boot/Image-5.15.147-sun60iw2-cyberdeck`
- Initrd: `/boot/initrd.img-5.15.147-sun60iw2-cyberdeck`
- DTB: `/boot/dtb-5.15.147-sun60iw2-cyberdeck/allwinner/sun60i-a733-orangepi-4-pro.dtb`

SD Ubuntu:

- Root UUID: `dc683cb4-0847-4d2f-83f1-184d35749d4c`
- Kernel: `/boot/vmlinux-5.15.147-sun60iw2`
- Initrd: `/boot/initrd.img-5.15.147-sun60iw2`
- DTB: `/boot/dtb-5.15.147-sun60iw2/allwinner/sun60i-a733-orangepi-4-pro.dtb`

The SD entry deliberately uses the stock kernel because the SD root only has
stock `5.15.147-sun60iw2` modules.

The extlinux entries include `bootchooser=extlinux-nvme` or
`bootchooser=extlinux-sd` in `APPEND`. If the menu is not visible on HDMI, check
`/proc/cmdline` after boot to distinguish a hidden extlinux boot from fallback
legacy `bootm`.

The direct `booti` probe used `bootchooser=direct-booti-nvme`. That marker was
not present after reboot, confirming fallback to legacy `bootm`.

## Validation

Run:

```bash
scripts/validate-boot-menu-assets.sh
```

This validates files, hashes, GRUB config syntax, and the expected UUID-bearing
menu entries. It cannot prove that vendor U-Boot has `bootefi`; that requires a
reboot or serial-console U-Boot command test.

## Rollback

Backups from before the boot-menu change:

- `/boot/boot.cmd.pre-grub-20260702T032242Z`
- `/boot/boot.scr.pre-grub-20260702T032242Z`
- `/boot/orangepiEnv.txt.pre-grub-20260702T032242Z`

Quick disable without restoring files:

```bash
sudo sed -i 's/^grub_first=.*/grub_first=false/' /boot/orangepiEnv.txt
sudo sed -i 's/^extlinux_first=.*/extlinux_first=false/' /boot/orangepiEnv.txt
sudo sed -i 's/^direct_booti_first=.*/direct_booti_first=false/' /boot/orangepiEnv.txt
sudo mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
sudo cp /boot/boot.scr /boot/efi/boot.scr
sudo cp /boot/orangepiEnv.txt /boot/efi/orangepiEnv.txt
sync
```

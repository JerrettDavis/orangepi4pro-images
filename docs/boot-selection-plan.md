# Boot Selection Plan

Current status on 2026-07-02:

- The machine boots NVMe Ubuntu through extlinux.
- The installed Orange Pi U-Boot can parse extlinux and boot the configured
  default entry.
- The installed Orange Pi U-Boot does not enable `CONFIG_USB_KEYBOARD` or
  `CONFIG_DM_KEYBOARD`, so it is not a reliable HDMI plus USB-keyboard boot
  selector.
- `TIMEOUT 0` is unsafe on this BSP. It has already wedged at the Orange Pi
  bootloader loading graphic.

## Safe Baseline

The committed safe baseline is a non-prompted extlinux dispatcher:

```text
PROMPT 0
TIMEOUT 30
DEFAULT ubuntu-nvme
```

`/boot/boot.cmd` uses plain partition-qualified `sysboot`, without `-p`:

```text
sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}extlinux/extlinux.conf
```

This should boot the configured default and avoid the broken prompt path.

## Selection Available Now

Selection is available from Linux by changing the default entry before reboot:

```bash
scripts/set-extlinux-default.sh --list
scripts/set-extlinux-default.sh ubuntu-sd
sudo scripts/set-extlinux-default.sh --apply ubuntu-sd
```

Return to NVMe:

```bash
sudo scripts/set-extlinux-default.sh --apply ubuntu-nvme
```

This is not an on-screen boot picker; it is the safe selector until U-Boot input
support is fixed.

## Required For On-Screen Selection

The next boot-time selector attempt must start from a U-Boot build that has:

- `CONFIG_MENU=y`
- `CONFIG_CMD_PXE=y`
- `CONFIG_DM_VIDEO=y`
- `CONFIG_USB_KEYBOARD=y`
- `CONFIG_DM_KEYBOARD=y`

The board-support repo has a build wrapper and fragment for this:

```bash
cd ../orangepi4pro-board-support
scripts/build-vendor-uboot.sh --bootmenu --clean
```

Do not flash this to NVMe, SPI, or the recovery SD until the Allwinner boot
package generation path is understood. The safe test target should be separate
recoverable media or a verified package image with documented rollback.

## Validation

Safe dispatcher files:

```bash
sudo scripts/validate-boot-menu-assets.sh
sudo mount -o ro /dev/mmcblk1p1 /mnt/opisd-ro
sudo scripts/validate-active-boot-source.sh /mnt/opisd-ro
```

Installed U-Boot capability check:

```bash
scripts/validate-u-boot-selector-capabilities.sh
```

Expected result today: the capability check fails on USB keyboard support.

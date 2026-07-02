# Boot Selection Plan

Current status on 2026-07-02:

- The machine boots NVMe Ubuntu through extlinux.
- The SD-card bootloader package has been replaced with a validated
  menu-capable vendor U-Boot package built from `v2018.05-sun60iw2` plus
  `CONFIG_CMD_BOOTMENU`, `CONFIG_USB_KEYBOARD`, and `CONFIG_DM_KEYBOARD`.
- The first reboot with the menu-capable package reached the NVMe desktop but
  showed a black screen before userspace, because the live boot files were
  still staged for the older extlinux visibility experiment.
- The current live boot files now call U-Boot `bootmenu` first, with a
  10-second default to NVMe, then continue through the known-good legacy
  `bootm` image path selected by menu variables.
- While the SD card is inserted, U-Boot reads `/boot/boot.scr` and
  `/boot/orangepiEnv.txt` from the SD root filesystem, even though Linux mounts
  NVMe `OPI_BOOT` at `/boot`. Always install selector assets to the SD `/boot`
  copy before reboot tests.
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

## Prompt Visibility Test

The bounded test mode for the current vendor U-Boot is:

```bash
sudo scripts/stage-extlinux-prompt-test.sh
sudo EXPECTED_EXTLINUX_PROMPT=1 \
  EXPECTED_EXTLINUX_TIMEOUT=100 \
  EXPECTED_SELECTOR_CONSOLE=true \
  scripts/validate-boot-menu-assets.sh
```

This does not write boot sectors or SPI flash. It mirrors the prompt-enabled
extlinux files to NVMe `/boot`, NVMe `/boot/efi`, and the SD boot source when
mounted at `/mnt/opisd-ro/boot`.

The staged state uses:

```text
PROMPT 1
TIMEOUT 100
DEFAULT ubuntu-nvme
bootlogo=false
logo=disabled
selector_console=true
selector_prompt=true
selector_bitmap=true
```

The expected behavior is a visible prompt/menu attempt followed by automatic
NVMe boot after about 10 seconds. The staged script also replaces `boot.bmp`
with a generated selector bitmap and has `boot.cmd` call `sunxi_show_bmp
boot.bmp`, because the vendor DRM logo path is visible even when the text
console is not. USB-keyboard selection may still fail on the installed U-Boot
because it lacks keyboard support; this test is meant to prove whether the
visible logo path can be controlled without flashing a new loader.

## Required For On-Screen Selection

The boot-time selector attempt now starts from a U-Boot build that has:

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

The Allwinner TOC1 package path is now understood in the board-support repo.
The SD-card bootloader slot was backed up before installing the menu-capable
package, and the installed bytes were read back and verified.

The current selector flow is:

```text
bootmenu_first=true
bootmenu_timeout=10
Ubuntu NVMe - cyberdeck kernel -> bootchooser=uboot-bootmenu-nvme
Ubuntu SD - stock kernel       -> bootchooser=uboot-bootmenu-sd
Ubuntu NVMe - verbose boot     -> bootchooser=uboot-bootmenu-nvme-verbose
```

After a test boot, inspect `/proc/cmdline`. A successful menu/default path
should contain one of the `uboot-bootmenu-*` markers instead of the older
`extlinux-legacy-*` marker.

The boot script also preloads a diagnostic fallback before invoking `bootmenu`:

```text
bootchooser=uboot-bootmenu-nosel
```

If that marker appears, U-Boot entered the menu branch but returned without a
selection. If `extlinux-legacy-*` still appears, U-Boot did not enter the menu
branch even though the synced boot files contain it.

## Validation

Safe dispatcher files:

```bash
sudo scripts/validate-boot-menu-assets.sh
sudo mount -o ro /dev/mmcblk1p1 /mnt/opisd-ro
sudo scripts/validate-active-boot-source.sh /mnt/opisd-ro
```

Install the same selector assets to NVMe `/boot`, NVMe `/boot/efi`, and the
active SD `/boot` copy:

```bash
sudo mkdir -p /mnt/opisd-ro
sudo mount -o ro /dev/mmcblk1p1 /mnt/opisd-ro
sudo scripts/install-extlinux-selector.sh /boot /boot/efi /mnt/opisd-ro/boot
sudo scripts/validate-active-boot-source.sh /mnt/opisd-ro
```

Installed U-Boot capability check:

```bash
scripts/validate-u-boot-selector-capabilities.sh
```

Expected result today: the capability check fails on USB keyboard support.

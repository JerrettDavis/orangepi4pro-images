# Boot Selection Plan

Current status on 2026-07-03:

- The machine boots NVMe Ubuntu through extlinux.
- The practical visible selector is now moving to early Linux on tty1, before
  LightDM. U-Boot remains the boot target router through a plain text
  `orangepiBootOnce.txt` file.
- The SD-card bootloader package is currently the recovered extlinux-first
  package. It scans `/boot/extlinux/extlinux.conf` before `/boot/boot.scr`.
- A validated menu-capable vendor U-Boot package was built from
  `v2018.05-sun60iw2` plus `CONFIG_CMD_BOOTMENU`, `CONFIG_USB_KEYBOARD`, and
  `CONFIG_DM_KEYBOARD`, then patched so `/boot/boot.scr` is scanned before
  extlinux. That package is not currently installed after recovery.
- A second file-only package candidate now embeds a static selector logo in
  vendor U-Boot's early-logo path instead of drawing a BMP from `boot.scr`.
- Reboots with the selector-logo package prove that script-first U-Boot enters
  `bootmenu` and boots the NVMe entry, because Linux reports
  `bootchooser=uboot-bootmenu-nvme`.
- The deck display still stays black during U-Boot and a blind Down+Enter test
  did not select SD, so keyboard input and display visibility remain unproven.
- The first reboot with the menu-capable package reached the NVMe desktop but
  showed a black screen before userspace, because the live boot files were
  still staged for the older extlinux visibility experiment.
- The repo selector templates can call U-Boot `bootmenu` first, with a
  20-second default to NVMe, then continue through the known-good legacy
  `bootm` image path selected by menu variables. The live recovered SD
  `boot.scr` is the conservative direct `bootm` script.
- While the SD card is inserted, U-Boot reads `/boot/boot.scr` and
  `/boot/orangepiEnv.txt` from the SD root filesystem, even though Linux mounts
  NVMe `OPI_BOOT` at `/boot`. Always install selector assets to the SD `/boot`
  copy before reboot tests.
- `TIMEOUT 0` is unsafe on this BSP. It has already wedged at the Orange Pi
  bootloader loading graphic.

## Early Linux Selector

U-Boot framebuffer diagnostics now prove the script path and framebuffer writes
run before Linux:

```text
bootchooser=uboot-visual-fbtest-ok
opi_fb_fbtest=ok,w=1024,h=600
opi_pre_drm=...init=1,en=1,bl=1,mode=1024x600...
opi_post_drm=...init=1,en=1,bl=1,mode=1024x600...
```

The panel still stays black until Linux userspace, so the visible selector is a
systemd service on `/dev/tty1`:

```bash
sudo scripts/install-linux-boot-selector.sh
sudo scripts/validate-linux-boot-selector.sh /
```

If the SD root is mounted, install the same clear/selector service there so a
one-shot SD request does not loop:

```bash
sudo mount /dev/mmcblk1p1 /mnt/opisd-check
sudo scripts/install-linux-boot-selector.sh --target-root /mnt/opisd-check
sudo scripts/validate-linux-boot-selector.sh /mnt/opisd-check
```

The selector writes this boot-readable file when SD is selected:

```text
/boot/orangepiBootOnce.txt
bootonce_target=sd
bootonce_source=linux-selector
```

`boot.cmd` imports that file before any U-Boot visual/menu experiments and sets
the known-good legacy image path directly:

```text
bootchooser=linux-selector-sd
bootchooser=linux-selector-nvme
```

The Linux service removes stale `orangepiBootOnce.txt` files at startup before
showing the menu, which prevents repeat SD boots after a successful one-shot
selection.

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
selector_bitmap=false
```

The expected behavior is a visible prompt/menu attempt followed by automatic
NVMe boot after about 10 seconds. Do not call `sunxi_show_bmp` from
`boot.scr`; that path hung the board during the video-first selector test.

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
bootmenu_timeout=20
bootmenu_default=nvme
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

## Script-First SD Boot Package

Installed and then later replaced during recovery on 2026-07-02:

```text
device=/dev/mmcblk1
package=/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-bootmenu-scriptfirst.fex
package_sha256=8a0393cbbbd27b980f8b7c2e9fc5070b3c1dd79aaf5b42f189f66daa00202289
u_boot_item_sha256=f57faf0cc956e639176f48996c2388cfbb8c749d5707d872b09249dcebef3845
backup=/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260702T222612Z.bin
backup_sha256=55dcadb7f255ad4c6489dd8fc34d07af2eac0d2110a06a20a2546775378f214e
```

The installed bytes were read back from `/dev/mmcblk1` at `bs=8192 skip=2050`
and matched the candidate package exactly. The package contains this compiled
distro scan order:

```text
run scan_dev_for_scripts
run scan_dev_for_extlinux
```

Current recovered SD bootloader readback contains the stock order:

```text
run scan_dev_for_extlinux
run scan_dev_for_scripts
```

## Selector-Logo Candidate

Installed for the next recovery-SD boot test on 2026-07-02:

```text
device=/dev/mmcblk1
package=/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-bootmenu-scriptfirst-selector-logo.fex
package_sha256=bad9dc0a68dd1c047982c85f13192a8759c16298f592785f18db1d8f74971007
u_boot_item_sha256=dfc59bbf7e4fe66f0ab2014fbe83e19ea7074a09e5c9c3740ee77fd77c51f89f
selector_bmp_sha256=bc3dcbd5a046168fe3b463b66da96cddafd84c0779c804f308b5d788c46bcb03
selector_bmp=320x240 24-bit Windows BMP, 230454 bytes
backup=/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260702T234205Z.bin
backup_sha256=9fabc67f143b3aa5e15ad17368684e5597196555891c886e92fc17a60ca2a4ec
```

The installed bytes were read back from `/dev/mmcblk1` at `bs=8192 skip=2050`
and matched the candidate for the exact 1388544-byte package length.

This keeps `boot.scr` on the script-first `bootmenu` path but removes the
unsafe `sunxi_show_bmp boot.bmp` call. The expected visual result is at least a
static selector/logo screen during the U-Boot window. If the text menu still is
not visible, test keyboard selection by pressing Down then Enter during the
timeout and checking `/proc/cmdline` after boot for
`bootchooser=uboot-bootmenu-sd`. The boot script explicitly runs `usb start`
before entering `bootmenu`; without that, U-Boot can expose `usbkbd` in
`stdin` while the USB keyboard stack is still stopped.

## Deterministic Bootmenu Tests

Use deterministic default-entry tests before more visual work. This avoids
guessing at a black screen.

Stage SD as bootmenu entry 0:

```bash
sudo scripts/stage-bootmenu-default-test.sh \
  --target sd \
  --sd-boot-dir /mnt/opisd-check/boot
sudo EXPECTED_BOOTMENU_DEFAULT=sd scripts/validate-boot-menu-assets.sh
```

After reboot, the pass condition is:

```bash
scripts/assert-bootchooser.sh uboot-bootmenu-sd
```

Restore NVMe as entry 0:

```bash
sudo scripts/stage-bootmenu-default-test.sh \
  --target nvme \
  --sd-boot-dir /mnt/opisd-check/boot
sudo EXPECTED_BOOTMENU_DEFAULT=nvme scripts/validate-boot-menu-assets.sh
```

After reboot, the pass condition is:

```bash
scripts/assert-bootchooser.sh uboot-bootmenu-nvme
```

## U-Boot Visual Diagnostics

The colorbar visual diagnostic avoids `sunxi_show_bmp` and does not rely on
menu input. It uses the vendor DRM test-pattern path:

```bash
sudo scripts/stage-uboot-visual-test.sh \
  --test colorbar \
  --hold 8 \
  --sd-boot-dir /mnt/opisd-check/boot
sudo EXPECTED_BOOTMENU_FIRST=false \
  EXPECTED_SELECTOR_VISUAL_TEST=colorbar \
  scripts/validate-boot-menu-assets.sh
```

After reboot, inspect the screen during the first 8 seconds and then assert the
marker:

```bash
scripts/assert-bootchooser.sh uboot-visual-colorbar-ok
```

When using a U-Boot package built with
`configs/u-boot/0002-add-sunxi-drm-env-diag.patch`, `/proc/cmdline` also
contains `opi_pre_drm=...` and `opi_post_drm=...` markers with U-Boot's display
route, connector type, mode, framebuffer dimensions, and backlight flag.

Interpretation:

- Colorbar visible and marker is `uboot-visual-colorbar-ok`: U-Boot can drive
  the panel; the remaining task is rendering a real selector on that path.
- No colorbar but marker is `uboot-visual-colorbar-ok`: the command returned
  success, but the visible route or backlight is still wrong.
- Marker is `uboot-visual-colorbar-fail`: U-Boot's DRM display list or TCON
  pattern path is not usable at that point in boot.

The 2026-07-03 native-mode colorbar test returned
`bootchooser=uboot-visual-colorbar-ok` and reported HDMI-A at `1024x600`,
49 MHz, with a 1024x600 framebuffer, but the screen stayed black until Linux.
The current visual diagnostic therefore bypasses the TCON pattern path and
paints directly into U-Boot's active DRM framebuffer:

```bash
sudo scripts/stage-uboot-visual-test.sh \
  --test fbtest \
  --hold 8 \
  --sd-boot-dir /mnt/opisd-check/boot
sudo EXPECTED_BOOTMENU_FIRST=false \
  EXPECTED_SELECTOR_VISUAL_TEST=fbtest \
  scripts/validate-boot-menu-assets.sh
```

After reboot, inspect the screen during the first 8 seconds and then assert:

```bash
scripts/assert-bootchooser.sh uboot-visual-fbtest-ok
```

The paired board-support package must contain `sunxi_drm fbtest`. A successful
run appends `opi_fb_fbtest=...` diagnostics to `/proc/cmdline`.

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

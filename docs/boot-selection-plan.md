# Boot Selection Plan

Current status on 2026-07-03:

- The machine boots NVMe Ubuntu through extlinux.
- The active target is bootloader-stage selection only. The temporary X11/XFCE
  autostart prompt was removed from the active path because it appears after a
  full Linux boot.
- The installed SD-card bootloader package is the stock vendor package with
  only script-first scan order patched. Readback from `/dev/mmcblk1` at
  `bs=8192 skip=2050` matches
  `boot_package_vendor-sd-scriptfirst.fex`, SHA-256
  `77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`.
- The SD `boot0_sdcard.fex` region at `bs=8192 skip=1` matches the vendor
  package. The missing bootloader display is not currently explained by a
  corrupted boot0 or partial TOC1 write.
- A validated menu-capable vendor U-Boot package was built from
  `v2018.05-sun60iw2` plus `CONFIG_CMD_BOOTMENU`, `CONFIG_USB_KEYBOARD`, and
  `CONFIG_DM_KEYBOARD`, then patched so `/boot/boot.scr` is scanned before
  extlinux. That package is not currently installed after recovery.
- A second file-only package candidate now embeds a static selector logo in
  vendor U-Boot's early-logo path instead of drawing a BMP from `boot.scr`.
- Reboots with the selector-logo package prove that script-first U-Boot enters
  `bootmenu` and boots the NVMe entry, because Linux reports
  `bootchooser=uboot-bootmenu-nvme`.
- The deck display still stays black during U-Boot. Blind Down+Enter tests have
  either kept booting NVMe or selected SD without a visible prompt, so keyboard
  input and display visibility remain unsuitable as a user-facing selector.
- The next bootloader-display candidate is built by the board-support script
  `scripts/prepare-vendor-sd-hdmi-power-package.sh`. It keeps stock vendor
  U-Boot, fixes script-first scanning, adds U-Boot's expected
  `uhdmi_power_count` property, and points HDMI power at phandles including a
  Linux-matching `cldo2` regulator node.
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

## Bootloader Request Files

U-Boot framebuffer diagnostics now prove the script path and framebuffer writes
run before Linux:

```text
bootchooser=uboot-visual-fbtest-ok
opi_fb_fbtest=ok,w=1024,h=600
opi_pre_drm=...init=1,en=1,bl=1,mode=1024x600...
opi_post_drm=...init=1,en=1,bl=1,mode=1024x600...
```

For logo-path diagnostics, stage the boot script with `extlinux_first=false`
and `selector_diag_force_bootm=true`. Extlinux `APPEND` lines replace the boot
script's `extraargs`, so `uboot-logo-preinit-*` markers are only visible in
`/proc/cmdline` when the test temporarily uses the legacy `bootm` path after
running `sunxi_show_logo`.

The boot script imports `orangepiBootOnce.txt` before extlinux or legacy
fallbacks. Request files must be mirrored to both NVMe `/boot` and SD `/boot`
because U-Boot may source `boot.scr` from either device:

```bash
sudo scripts/install-linux-boot-selector.sh
sudo scripts/validate-linux-boot-selector.sh /
```

If the SD root is mounted, install the same request-file helper there so a
one-shot request can be mirrored and later cleared:

```bash
sudo mount /dev/mmcblk1p1 /mnt/opisd-check
sudo scripts/install-linux-boot-selector.sh --target-root /mnt/opisd-check
sudo scripts/validate-linux-boot-selector.sh /mnt/opisd-check
```

The helper writes this boot-readable file when SD is selected:

```text
/boot/orangepiBootOnce.txt
bootonce_target=sd
bootonce_source=linux-selector
```

When running from the SD root, the same helper writes
`bootonce_target=nvme` so the next boot returns to NVMe Ubuntu.

`boot.cmd` imports that file before any U-Boot visual/menu experiments and sets
the known-good legacy image path directly:

```text
bootchooser=linux-selector-sd
bootchooser=linux-selector-nvme
```

The Linux cleanup service removes stale `orangepiBootOnce.txt` files at startup
before LightDM, which prevents repeat one-shot boots after a successful
selection. It does not present a userland boot menu.

## Safe Baseline

The committed safe baseline is a non-prompted boot script default:

```text
extlinux_first=false
bootmenu_first=false
bootchooser=boot-script-default-nvme
```

`/boot/boot.cmd` explicitly sets the known-good NVMe legacy image path when no
one-shot target is present:

```text
uImage-5.15.147-sun60iw2-cyberdeck
uInitrd-5.15.147-sun60iw2-cyberdeck
root=UUID=eb86cfeb-60c7-4513-bc69-f6d28e9d561b
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

Current staged test:

- U-Boot package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-diagnostic-fbtest-hdmi-power.fex`
- Package SHA-256:
  `fcfac8e4e89b6b4c5237bc7649064f3a9bf0d3d85a4b64a5eddd47e3b3ec8d81`
- Boot env:
  `selector_visual_test=fbtest`, `selector_visual_hold=20`,
  `selector_logo_preinit=false`, `selector_diag_force_bootm=false`.
- Expected marker after reboot:
  `bootchooser=uboot-visual-fbtest-ok` or
  `bootchooser=uboot-visual-fbtest-fail`.
- If the screen remains black but the marker is `ok`, inspect the attached
  `opi_pre_*`, `opi_fb_*`, and `opi_post_*` diagnostics in `/proc/cmdline`
  before changing display strategy again.

2026-07-03 first attempt result:

- The system booted NVMe with `bootchooser=boot-script-default-nvme`.
- Root cause: the default NVMe branch in `boot.cmd` cleared
  `selector_visual_test` before the `fbtest` block, so the framebuffer test did
  not execute.
- Fix: the default NVMe branch now leaves `selector_visual_test` intact, and
  `scripts/validate-boot-menu-assets.sh` fails if that branch reintroduces
  `setenv selector_visual_test none`.

2026-07-03 second attempt result:

- The system booted NVMe with `bootchooser=uboot-visual-fbtest-ok`.
- U-Boot reported HDMI-A initialized and enabled at `1024x600`, and
  `opi_fb_fbtest=ok,w=1024,h=600,addr=b3dfd000,size=2457600`.
- The next package is
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-fbtest-planecommit-hdmi-power.fex`,
  SHA-256
  `19f2f5fb2874f9c836963921cf63fa66be652948f2fdbdb87ccf938dd8696c85`.
  It updates `sunxi_drm fbtest` to bind the painted framebuffer to the primary
  plane and flush the CRTC before the 20 second hold.
- Expected marker after reboot remains `bootchooser=uboot-visual-fbtest-ok`,
  with `opi_fb_fbtest=...fbid=...,plane=...,en=...`.

2026-07-03 third attempt result:

- The system booted NVMe with `bootchooser=uboot-visual-fbtest-ok`.
- U-Boot reported `opi_fb_fbtest=ok,...fbid=0,plane=0,en=1`, proving the
  active framebuffer was committed to the primary plane.
- The next package is
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-fbtest-planecommit-hdmi-power-tconclk.fex`,
  SHA-256
  `2a4268c4dc2ce8f5731c87390e555ceeabd12b0f4223739675bbb2bb374154a9`.
  It adds the missing `clk_tcon_tv` clock-name to the packed U-Boot HDMI node
  so `_sunxi_drv_hdmi_set_rate()` can set the HDMI clock from the active TCON
  clock before enabling output.
- Expected marker after reboot remains `bootchooser=uboot-visual-fbtest-ok`,
  with the same `opi_fb_fbtest=...fbid=0,plane=0,en=1` marker. The visual pass
  condition is a visible high-contrast framebuffer test during the 20 second
  U-Boot hold.

2026-07-03 fourth attempt plan:

- Keep the installed TCON-clock U-Boot package and switch only the staged boot
  script to `selector_visual_test=hdmi20_pattern`.
- This runs `sunxi_hdmi20 pattern 1`, the vendor DesignWare HDMI internal
  pattern generator, then holds for 20 seconds before legacy NVMe boot.
- Expected marker after reboot:
  `bootchooser=uboot-visual-hdmi20-pattern-ok` or
  `bootchooser=uboot-visual-hdmi20-pattern-fail`.
- If the HDMI20 pattern is also invisible, the remaining fault is link
  bring-up below framebuffer/DE/TCON plane rendering. If it is visible, move
  back upward to TCON source selection and framebuffer scanout.

2026-07-03 fourth attempt result and fifth attempt plan:

- The system booted NVMe with
  `bootchooser=uboot-visual-hdmi20-pattern-fail`.
- Source inspection found that
  `_sunxi_hdmi_sysfs_pattern_store()` always returned `1`, even after taking
  its documented pattern branch. The `fail` marker is therefore not reliable
  hardware evidence.
- The next package fixes that return value and exports
  `opi_pat_hdmipat=req...,tcon...,force...,r...,g...,b...` so Linux records
  whether U-Boot actually set the DesignWare HDMI frame-composer force-video
  registers before the 20 second hold.
- Next package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-patternstatus-1024x600.fex`,
  SHA-256
  `2b79a35b9182a63a4304cb89aa1b1178fe214abe03050923b212a06e05a24abd`.
  This returns to the 1024x600 clock that Linux uses successfully on this
  display, keeps the script-first AW_DRM diagnostic U-Boot path, and carries
  the HDMI power/clock DTB corrections.
- Staged script mode remains:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20`.
  Expected marker after reboot should become
  `bootchooser=uboot-visual-hdmi20-pattern-ok` plus the `opi_pat_*`
  diagnostics. If the screen is still black, use those diagnostics to decide
  whether the remaining failure is before or after HDMI frame-composer output.

2026-07-03 fifth attempt result and sixth attempt plan:

- The system booted NVMe with `bootchooser=extlinux-legacy-nvme`, proving
  U-Boot entered the extlinux dispatcher and selected the default NVMe entry.
- Visual selector output is still missing, so the current fault is U-Boot video
  console routing rather than storage detection or selector dispatch.
- Next staged script mode:
  `scripts/stage-extlinux-prompt-selector.sh --timeout 200 --default ubuntu-nvme --video-console true`.
  This forces the existing `selector_console=true` branch before extlinux, which
  runs `usb start`, sets `stdin=serial,usbkbd`, sets
  `stdout/stderr=vidconsole,serial`, clears the screen, and then enters
  `sysboot -p`.

2026-07-03 sixth attempt result and seventh attempt plan:

- The forced-vidconsole path still booted NVMe through extlinux with
  `bootchooser=extlinux-legacy-nvme`.
- Next package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst.fex`,
  SHA-256
  `77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`.
- This is the closest stock-vendor candidate: it preserves the factory U-Boot
  DTB and display/logo code, changing only the distro scan order so `boot.scr`
  runs before extlinux. It still contains `sunxi_show_logo`,
  `boot.bmp decompressed OK`, `NVMe detected ==> using embedded boot.bmp array`,
  and `vidconsole`.
- Keep the staged extlinux selector with `selector_console=true` for this test.
  If the factory splash returns, continue from this package instead of the
  HDMI-power DTB-patched package.

2026-07-03 seventh attempt result and eighth attempt plan:

- The minimal stock script-first package still booted NVMe through extlinux
  with `bootchooser=extlinux-legacy-nvme`.
- Next staged script mode:
  `scripts/stage-extlinux-prompt-selector.sh --timeout 200 --default ubuntu-nvme --video-console true --logo-preinit true --logo-hold 5`.
- This keeps the closest-to-factory U-Boot package and explicitly runs the
  stock `sunxi_show_logo` path before switching stdout/stderr to vidconsole and
  entering prompted extlinux. The goal is to restore the same video
  initialization path that produced the factory "boot loader initializing"
  display before asking U-Boot to render selector text.

2026-07-03 eighth attempt result and ninth attempt plan:

- The system still booted NVMe through extlinux with
  `bootchooser=extlinux-legacy-nvme`.
- Because `sysboot` uses the fixed `APPEND` lines from `extlinux.conf`, the
  `boot.cmd` logo-preinit marker cannot be observed in `/proc/cmdline`.
- Next package:
  `/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package.fex`,
  SHA-256
  `7a2661b080f5c5d8ba32566bc79f1ccfbfb8912a4a5c0c1a4856a9380542c807`.
- This is the exact vendor package. It restores the original extlinux-first
  scan order and the factory U-Boot DTB/display path while preserving the
  prompted extlinux selector files on the boot filesystems. Use this to test
  whether the factory "boot loader initializing" display returns when no
  U-Boot binary patch is present.

2026-07-03 ninth attempt result and tenth attempt plan:

- Exact vendor U-Boot still booted the NVMe extlinux entry:
  `bootchooser=extlinux-legacy-nvme`.
- Exact vendor U-Boot scans extlinux before `boot.scr`, so the scripted
  `selector_console=true` branch cannot run in that package.
- Return to the minimal script-first package and update the selector console
  branch to set `stdout/stderr=serial,vidconsole` instead of
  `vidconsole,serial`, then clear and print an explicit marker before extlinux.
  Serial stays as the guaranteed console while vidconsole is added for HDMI
  rendering.

2026-07-03 HDMI clock-route diagnostic plan:

- Previous U-Boot diagnostics reached Linux with
  `bootchooser=uboot-visual-fbtest-ok` and reported valid HDMI route state,
  framebuffer setup, HPD, selected 1280x720 mode, and top PHY lock, but both
  exported HDMI/TCON clock readings remained `24000000`.
- The next package is
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-clockroute-720p.fex`.
  It keeps the same bounded `fbtest` visual path but changes the packed U-Boot
  DTB so `clk_hdmi` points at the programmable `hdmi_tv` clock and the old gate
  is exposed as `clk_bus_hdmi`. The U-Boot HDMI driver also falls back to the
  selected mode clock when the TCON clock reads as 0 or stale 24 MHz.
- Expected post-reboot evidence if this fixes pre-OS HDMI signaling:
  `opi_post_hdmi` should report `hdmi74250000` for the 720p test, and the user
  should see the high-contrast bootloader framebuffer test before the Orange Pi
  OS loader.

2026-07-03 HDMI bus-clock diagnostic plan:

- The clock-route package proved the HDMI TV clock can be programmed:
  `opi_post_hdmi` reported `hdmi74250000`. The display still showed no
  bootloader visual, and diagnostics reported `toplock0` plus zeroed top PHY
  registers.
- The next package is
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-busclock-720p.fex`.
  It keeps the clock-route DTB binding and adds a U-Boot source patch to enable
  the parsed `clk_bus_hdmi` gate before the HDMI clocks are used.
- Expected post-reboot evidence: the high-contrast bootloader framebuffer test
  should be visible. If it is still not visible, `opi_post_hdmi` should show
  whether the top PHY returned to nonzero locked state or whether the remaining
  failure moved elsewhere.

2026-07-03 AW_DRM versus legacy bootGUI finding:

- The installed HDMI bus-clock package reached Linux with
  `bootchooser=uboot-visual-fbtest-ok`. U-Boot reported HPD, a 1280x720 mode,
  a 74.25 MHz HDMI clock, nonzero HDMI TOP registers, `toplock1`, and a
  successful framebuffer paint into the active U-Boot DRM framebuffer. The
  external display still remained black until the later Orange Pi OS loader.
- The obvious legacy `bootGUI` canvas path is not usable for this A733 build.
  In the vendor U-Boot tree, `CONFIG_BOOT_GUI` depends on `CONFIG_DISP2_SUNXI`;
  the sun60iw2/A733 defconfig uses the newer AW_DRM display stack instead.
  Enabling `CONFIG_DISP2_SUNXI` for this target fails to compile in
  `drivers/video/sunxi/disp2` with "undefined platform" errors. Selector work
  should stay on the AW_DRM/HDMI20 path unless the vendor adds sun60iw2 DISP2
  platform support.
- The next bootloader-only diagnostic is the HDMI20 controller pattern
  generator:

```bash
sudo scripts/stage-uboot-visual-test.sh \
  --test hdmi20_pattern \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

This bypasses the DE/TCON/framebuffer drawing path. If the pattern is visible,
the remaining failure is in the AW_DRM plane/framebuffer rendering path. If the
pattern is still invisible, U-Boot's HDMI link/output is not actually reaching
the display even though the current diagnostics report success.

2026-07-03 factory logo filename finding:

- The post-reboot HDMI pattern-status test reached Linux with
  `bootchooser=uboot-visual-hdmi20-pattern-ok` and
  `opi_pat_hdmipat=req1,tcon0,force01,rff,g00,b00`, proving U-Boot set the
  DesignWare frame-composer force-video registers for a red output. The display
  still showed no pre-OS image.
- The SD `boot0_sdcard.fex` region byte-matches the vendor file, so the
  missing factory splash is not explained by boot0 corruption.
- The current A733 U-Boot logo loader searches `/boot/boot1.bmp` and
  `/boot/boot.bmp`. The Orange Pi factory-style asset still exists as
  `/boot/logo.bmp` and `/boot/efi/logo.bmp`, but `boot.bmp` and `boot1.bmp`
  had been replaced with the generated 320x240 selector/test bitmap.
- Stage the next test with:

```bash
sudo scripts/stage-factory-logo-preinit-test.sh \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

This restores `logo.bmp` to the filenames U-Boot actually loads, runs
`sunxi_show_logo`, holds for 20 seconds, and then boots NVMe through the
known-good legacy `bootm` path. Expected Linux evidence is
`bootchooser=uboot-logo-preinit-ok` plus `opi_logo_*` HDMI diagnostics.

2026-07-03 stock BootGUI reset-point test:

- The factory Orange Pi "initializing boot loader" display is the behavior to
  recover first. The next test should stop using the custom selector U-Boot
  binary and reinstall the stock vendor SD U-Boot package with only the
  script-first scan-order patch:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst.fex`.
- Expected SHA-256:
  `77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`.
- Preinstall validator:

```bash
/home/orangepi/orangepi4pro-board-support/scripts/validate-stock-bootgui-package.sh \
  --package /var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst.fex
```

- Stage boot assets for an actual selector attempt, not a userland fallback:

```bash
sudo scripts/stage-extlinux-prompt-selector.sh \
  --timeout 200 \
  --default ubuntu-nvme \
  --video-console true \
  --logo-preinit false \
  --extlinux-first true
```

The expected visual result is the factory boot-loader splash first, followed by
the U-Boot/extlinux selector window. If only the factory splash returns, the
next patch should draw the selector through the same early display path rather
than through the custom AW_DRM framebuffer/pattern-test path.

2026-07-03 HDMI rich-register diagnostic test:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-richdiag-1024x600.fex`
- Package SHA-256:
  `d765d346f939de1438843a195b291cc7b9816c757da70b51d654876f1f815ba8`
- Staged boot assets:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20 --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: hold U-Boot for 20 seconds while the HDMI20 controller internal
  pattern generator is enabled. This bypasses framebuffer drawing and records
  richer HDMI transmitter registers into the next Linux command line.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok` and `opi_pre_*`, `opi_pat_*`,
  and `opi_post_*` command-line fields. If the monitor still reports no signal,
  inspect the recorded `phy`, `stat`, `rst`, `lock`, `vid`, and `gcp` register
  bytes before making the next display patch.

2026-07-03 top-PHY PDDQ visual retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-toppddq-1024x600.fex`
- Package SHA-256:
  `d16c515ab57b1f2747d3706973633eed2b7a8ea47c1f3f90fbf398e0b0f28f37`
- Staged boot assets:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20 --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: repeat the same 20-second HDMI20 internal pattern test after clearing
  the sun60i top-PHY `phy_pddq` bit during U-Boot top-PHY power-on.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok` and `opi_pre_hdmi=*top0_*`
  with bit 1 clear, ideally changing the prior `top0_00000017` reading to
  `top0_00000015`.

2026-07-03 corrected top-PHY PDDQ retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-toppddq-applied-1024x600.fex`
- Package SHA-256:
  `ee6df304753d62319a499f148d9e56b8a5f065f27548672ccb955f9cd93fc2a7`
- Note: this supersedes the earlier `d16c515a...` top-PHY package, which was
  built before the new `0013` patch was wired into the U-Boot build script.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok` and `opi_pre_hdmi=*top0_*`
  changing away from the previous `top0_00000017` reading.

2026-07-03 HDMI pattern reconfiguration retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-pattern-reconfig-1024x600.fex`
- Package SHA-256:
  `5e1e7209d7fe8535c998c640593f280a6b8f94f7afc4115cb11218189687d92d`
- U-Boot item SHA-256:
  `56e9e8e882485333850f928920f0d79914e0fd36b8f5a7af8ff2099301bae972`
- Staged boot assets:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20 --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: repeat the 20-second HDMI20 internal pattern test, but first force
  the vendor HDMI driver through `_sunxi_drv_hdmi_enable()` because the last
  captured U-Boot registers showed a powered top PHY with the DesignWare HDMI
  core still idle.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok` and
  `opi_pat_hdmipat=req1,reconfig0,...`. If HDMI is still not visible before
  Linux, inspect whether the `phy`, `stat`, `rst`, `lock`, `vid`, and `gcp`
  fields changed from zero.

2026-07-03 stock-SD factory display plus prompted selector retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst.fex`
- Package SHA-256:
  `77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`
- U-Boot item SHA-256:
  `94e5aa1cdebde42ce773f8d476fe78891cc61ad7e9e839d2554d738a549d55f5`
- Source stock SD package:
  `/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package.fex`
- Source stock SD package SHA-256:
  `7a2661b080f5c5d8ba32566bc79f1ccfbfb8912a4a5c0c1a4856a9380542c807`
- Source references checked:
  `orangepi-xunlong/u-boot-orangepi` branch `v2020.04` commit
  `c97dbbcad55f5a1e40c28b1a9874b2e0b9f163c9`; CarterPerez NVMe research repo
  branch `main` commit `fe4c31ec0115d3f2493905be07426f36f666aab5`.
- Staged boot assets:
  `scripts/stage-extlinux-prompt-selector.sh --timeout 200 --default ubuntu-nvme --video-console true --logo-preinit true --logo-hold 8 --extlinux-first true --diag-force-bootm false --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: restore the factory display path first. The package uses the stock SD
  U-Boot logo/display code and only patches distro scan order so `boot.scr`
  runs. The script calls stock `sunxi_show_logo`, holds for 8 seconds, routes
  output to `serial,vidconsole`, and enters prompted extlinux.
- Expected result: the Orange Pi boot-loader splash or another stock-logo
  display should be visible before the selector. If no key is pressed, the
  extlinux default should boot NVMe with `bootchooser=extlinux-legacy-nvme`.

2026-07-03 HDMI full-reinit pattern retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-fullreinit-pattern-1024x600.fex`
- Package SHA-256:
  `5c70ff4fd05d4983ccaba08e22efece301ce2bf745618b0b1b46721823502a45`
- U-Boot item SHA-256:
  `e852404440cf42e0f7e9bcdb72306d6d11d436a32ddf0377090b2ba69666cead`
- Staged boot assets:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20 --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: repeat the HDMI20 pattern test after changing the U-Boot diagnostic
  from low-level HDMI enable to full HDMI DRM disable, mode-set, and enable.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok` and
  `opi_pat_hdmipat=req1,reconfig0,...`, ideally with nonzero `opi_post_hdmi`
  core fields or a visible pre-OS red pattern.

2026-07-03 HDMI reinit stage-diagnostic retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-reinitdiag-pattern-1024x600.fex`
- Package SHA-256:
  `78b54a1b96aea7ca0456d8085d915e2eaedcffef6117e7d4ca6889eeb87c50e7`
- U-Boot item SHA-256:
  `ad176262afd51248a3c61ccff72185a66bea7fbf2916a012b0c3112210a0facf`
- Staged boot assets:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20 --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: keep the bounded HDMI20 internal red-pattern test, but record the
  true internal U-Boot HDMI reinit stage returns and register state in
  `opi_reinit_reinit=...`.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok`,
  `opi_pat_hdmipat=req1,...`, and `opi_reinit_reinit=d...,x...,m...,t...`.
  If there is still no pre-OS image, use that field to identify whether TCON
  init, HDMI clocking, `sunxi_hdmi_config()`, TOP PHY, or DesignWare core state
  is the remaining blocker.

2026-07-03 DRM full-display reinit plus HDMI pattern retest:

- Installed SD TOC1 package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-drm-reinit-hdmi-pattern-1024x600.fex`
- Package SHA-256:
  `34f52a23883a427d6471bdfc69654ef853a6f96a1f406a732acd64a35555852f`
- U-Boot item SHA-256:
  `bf4cbf09c7f910d4f3d9a8be3914606d7c5023a0bb6a63907c5cc96fb1f0fdf0`
- Staged boot assets:
  `scripts/stage-uboot-visual-test.sh --test hdmi20_pattern --hold 20 --sd-boot-dir /mnt/opisd-rw/boot`
- Intent: run the full U-Boot DRM display disable/init/enable path before the
  bounded HDMI20 red-pattern test, instead of only reinitializing the HDMI
  connector.
- Expected Linux evidence:
  `bootchooser=uboot-visual-hdmi20-pattern-ok`,
  `opi_drmre_ok,drmreinit=...`, `opi_pat_hdmipat=req1,...`, and non-masked
  DesignWare HDMI register values in the HDMI diagnostic fields.
- Actual result: unsafe. This package failed to complete a normal boot and
  required external SD recovery from another machine.
- Blocked package SHA-256:
  `34f52a23883a427d6471bdfc69654ef853a6f96a1f406a732acd64a35555852f`
- Current recovered baseline:
  `/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package_a733_nvme.fex`
  with SHA-256
  `e626234a6eb9420ac29f515dd6acc543e7f0876e3dc086eec2fe221a50cc54f2`,
  byte-matched in the SD bootloader slot and booting NVMe with
  `bootchooser=extlinux-legacy-nvme`.

2026-07-03 factory-logo preinit result:

- The script-first vendor NVMe package
  `boot_package_vendor-nvme-scriptfirst.fex`, SHA-256
  `d798104ccd705e542842fac409b1e2694c6ca19fcfac75fc30036a4535a7d318`,
  booted through the SD boot script and reached Linux with
  `bootchooser=uboot-logo-preinit-ok bootchooser=boot-script-default-nvme`.
- The screen still stayed black until the Linux/Ubuntu splash. That proves
  `sunxi_show_logo` can return success while pre-Linux HDMI remains invisible.

2026-07-03 HDMI TCON clock-sequence candidate:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-tconseq-1024x600.fex`
- Package SHA-256:
  `18ed3b2a21c7c5a4563d21b426a2b0b34a972312c2bb0d1394ddfee74e199d49`
- U-Boot item SHA-256:
  `5cc7a6837af0f3ced7a554c9d5704bbdee056f3efa2af7b43a0dcedbf8d3df18`
- Intent: change only the HDMI TCON clock/reset preparation sequence to better
  match Linux's working 1024x600 mode-change path. The known-unsafe full DRM
  reinit diagnostic remains disabled.

2026-07-03 HDMI frame-composer iteration candidate:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-fciter-1024x600.fex`
- Package SHA-256:
  `a6ff4344d16002f4274a30fee0c4ed861fb6e4e1cedd9251a810ab38e69a2db0`
- U-Boot item SHA-256:
  `531c73cf5f7ace30e2dfba95e52a0beaa3beccf830984f92d5a259649967e556`
- U-Boot build artifact SHA-256:
  `002934b2dec68ac776a3fa1dd1c84ff15d13ab0ebe0753d76ffb01b1c5b7bd11`
- Source patch:
  `orangepi4pro-board-support/configs/u-boot/0019-sync-linux-hdmi-fc-iteration-and-diag.patch`
- Intent: keep the script-first factory-logo preinit test, but add Linux's
  missing HDMI20 frame-composer iteration write to U-Boot AVP config and read
  DesignWare HDMI registers unconditionally for better post-boot diagnosis.
- Safety: the previously unsafe full DRM reinit command remains disabled and
  must not appear in the packaged U-Boot strings.
- Follow-up script safety: the `hdmi20_pattern` boot-script path now records
  `drmreinit=disabled` and must not invoke `sunxi_drm reinit`; the pattern
  test should exercise only the HDMI20 internal pattern command plus the
  current U-Boot HDMI register diagnostics.

2026-07-03 HDMI RX-sense wait candidate:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-rxsense-1024x600.fex`
- Package SHA-256:
  `59fe28f8c629ff194e413cc7dd2878c6a6aec7103744a0422a4a1c537576d3ff`
- U-Boot build artifact SHA-256:
  `7c9c6e781017a82dff400f5e31049cfdf69563d39b0b6d91aff2d5e31b5a4610`
- U-Boot item SHA-256:
  `1f0cd3409f43a11909f3b18f199554258c69b434332bbd8bf61e6fa05c07498b`
- Intent: keep the HDMI20 internal pattern test but wait up to 100 ms after
  SNPS PHY lock for RX-sense lane status before handing control back to the
  boot script.
- Safety: no full DRM reinit command; timeout is non-fatal and should still
  boot through the known NVMe legacy `bootm` path.

2026-07-03 stock vendor extlinux result:

- The exact stock vendor NVMe package
  `/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package_a733_nvme.fex`,
  SHA-256 `e626234a6eb9420ac29f515dd6acc543e7f0876e3dc086eec2fe221a50cc54f2`,
  booted the prompted extlinux NVMe entry and reached Linux with
  `bootchooser=extlinux-legacy-nvme`.
- The screen still stayed black until the Orange Pi OS splash/desktop. This
  proves the extlinux selector is logically reached, but stock U-Boot is not
  presenting a visible video console before Linux initializes HDMI.

2026-07-03 standard BMP-display selector test:

- `configs/boot.cmd` now has a guarded `selector_bitmap=true` path that uses
  standard U-Boot `bmp display ${load_addr}` instead of the unsafe BSP
  `sunxi_show_bmp` command.
- The next bounded test stages a plain white `800x480` `boot.bmp` on NVMe and
  SD boot filesystems, sets `selector_bitmap=true`, holds for
  `selector_visual_hold`, and can force the known-good legacy NVMe `bootm`
  path with `selector_diag_force_bootm=true` so the Linux command line keeps
  `bootchooser=uboot-bmp-display-ok|fail`. If this path works, the pre-Linux
  screen should go visibly white before the default boot continues. If it
  remains black/no-signal but Linux reaches `uboot-bmp-display-ok`, the
  standard U-Boot video console is also writing to an unscanned or disconnected
  framebuffer before Linux reinitializes HDMI.
- Reboot result: Linux reached
  `bootchooser=uboot-bmp-display-ok`, proving that U-Boot loaded the white BMP
  and the standard `bmp display ${load_addr}` command returned success before
  the legacy NVMe boot continued. The screen still did not show a pre-OS image.
  This rules out a missing boot script or failed BMP decode; the remaining
  blocker is U-Boot display scanout/signal visibility before Linux reinitializes
  HDMI.

2026-07-03 staged stock-logo preinit diagnostic:

- Current installed SD TOC1 package remains
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-nvme-scriptfirst.fex`,
  SHA-256 `d798104ccd705e542842fac409b1e2694c6ca19fcfac75fc30036a4535a7d318`.
- Extracted package strings confirm the vendor U-Boot still contains
  `sunxi_show_logo`, `boot.bmp decompressed OK`, and the Orange Pi upstream
  embedded BMP fallback for NVMe.
- The next staged test disables the standard BMP diagnostic, sets
  `selector_logo_preinit=true`, holds for 10 seconds, and forces the known-good
  legacy NVMe `bootm` path so the kernel command line should preserve
  `bootchooser=uboot-logo-preinit-ok|fail`.
- This test intentionally writes only boot filesystem assets. It does not
  install a new U-Boot package or touch NVMe/SD bootloader sectors.
- Reboot result: Linux reached `bootchooser=uboot-logo-preinit-ok`, proving
  the stock `sunxi_show_logo` path returned success. The display still had no
  pre-OS image, and the stock package lacked `sunxi_hdmi_env`, so the recorded
  HDMI diagnostic was only `opi_logo_hdmi=diag-missing`.

2026-07-03 passive HDMI/DRM diagnostic package:

- The next candidate is
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-passive-diag.fex`,
  SHA-256 `71cb5564f5d7249bece9c35a449bb199a9b6836dcb3f8dd2b946bea61b6b8ceb`.
- It is built from Orange Pi U-Boot `v2018.05-sun60iw2`
  `b791be842935b27268ae3d00e943a9075495f30a` with only script-first scan order
  and passive `sunxi_drm_env`/`sunxi_hdmi_env` commands. It does not contain
  `sunxi_drm reinit`.
- The staged boot script still runs `sunxi_show_logo`, holds for 10 seconds,
  and forces the known-good legacy NVMe `bootm` path. Expected post-reboot
  evidence is `bootchooser=uboot-logo-preinit-ok` plus `opi_logo_hdmi=...` and
  `opi_logo_drm=...` in `/proc/cmdline`.
- Reboot result: Linux reached `bootchooser=uboot-logo-preinit-ok`, but the
  display still showed no bootloader image before the OS splash. U-Boot
  reported `mode=1920x1080`, `clk=148500`, `fbw=1920`, `fbh=1080`, and
  `hdmi24000000`, while Linux later switched to the visible 1024x600 path.

2026-07-03 forced cyberdeck-mode diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024.fex`
- Package SHA-256:
  `be973352edaf182a456dc3618a91c17b12df4ba54ec4d0d8e8aa91aed8c48516`
- U-Boot item SHA-256:
  `f56647ab3a8e1fa464e6fcf8d5731ef76c4b2ca4b5bd838ee75cc93318c65419`
- This package keeps the script-first boot path and passive diagnostics, but
  forces U-Boot's HDMI mode selection to `1024x600@49 MHz` and programs
  `clk_hdmi` from the selected mode when the TCON clock is stale. It preserves
  the vendor monitor/SCP blobs and does not contain `sunxi_drm reinit`.
- Expected post-reboot evidence is still
  `bootchooser=uboot-logo-preinit-ok`; the important diagnostic change should
  be `opi_logo_drm=...mode=1024x600,clk=49000...` and
  `opi_logo_hdmi=...hdmi49000000,pix49000,tmds49000...`.
- Reboot result: the mode portion succeeded and Linux booted from NVMe with
  `opi_logo_drm=...mode=1024x600,clk=49000,fbw=1024,fbh=600...`. The display
  still did not show a bootloader image because HDMI diagnostics still reported
  `tcon0,hdmi24000000,pix49000,tmds49000`.

2026-07-03 HDMI clock-binding diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmiclkdtb.fex`
- Package SHA-256:
  `78a8c9b079d96d33a396b1b1fc9f5bcf85c8fe80aee56e3777e20002bf3f5134`
- U-Boot item SHA-256:
  `65a9d1bec87a9d7e0dd41197ffc3f242f9437d342beae7d4f5eeccd1a2d9d5a6`
- This package keeps the successful forced 1024x600 diagnostic U-Boot and
  patches the embedded U-Boot DTB so `clk_hdmi` maps to the programmable
  `hdmi_tv` clock and the original HDMI gate maps to `clk_bus_hdmi`. It also
  applies the existing HDMI power/fast-output DTB corrections with
  `force_route=false`.
- Expected post-reboot evidence is still
  `bootchooser=uboot-logo-preinit-ok`; the key diagnostic change should be
  `opi_logo_hdmi=...hdmi49000000,pix49000,tmds49000...`, or a new error that
  proves where HDMI clock programming still fails.
- Reboot result: Linux reached NVMe, but both bootloader diagnostics regressed
  to `opi_logo_hdmi=diag-missing` and `opi_logo_drm=diag-missing`. The package
  byte-matched the SD bootloader slot and still contained the command strings,
  so the broader embedded-DTB power/clock/fast-output patch is not a useful
  diagnostic baseline.

2026-07-03 HDMI clock-only diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmiclkonly.fex`
- Package SHA-256:
  `30a2e74b02aaaef585c38775c8cf31b73763a0f4ed09d563d1e3c3d213b91ddd`
- U-Boot item SHA-256:
  `c2b16f210805d35bae323bd646855c8e29e7e6763d5c14989a5d278e39f75d48`
- This package keeps the successful forced 1024x600 diagnostic U-Boot and
  patches only the embedded U-Boot DTB HDMI clock bindings:
  `clk_tcon_tv clk_hdmi clk_hdmi_24M clk_bus_hdmi rst_main rst_sub`. It does
  not add HDMI power properties, fast-output, or route forcing.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`; the useful outcomes are either retained
  diagnostics with `hdmi49000000`, or retained diagnostics with `hdmi24000000`
  proving the clock binding alone is not enough.
- Reboot result: Linux reached the NVMe root, but U-Boot reported
  `opi_logo_hdmi=drm-missing` and `opi_logo_drm=missing`. That means even the
  clock-only embedded-DTB rewrite prevents U-Boot from finding an initialized
  DRM display list at boot-script time. The next candidate returns to the stock
  embedded DTB and moves the HDMI TV clock change into U-Boot code.

2026-07-03 HDMI TV clock fallback diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk.fex`
- Package SHA-256:
  `000821770992c9124c51dddc360fb6dcd45f9bbe7f6c88bc72e07fdc953fa532`
- U-Boot item SHA-256:
  `30173d1158694386a13d44a60f5a6dfca551ecc4640726a9fd0b8f8b6e0ce2e8`
- This package preserves the stock embedded U-Boot DTB and vendor monitor/SCP
  blobs. It keeps forced `1024x600@49 MHz` mode selection, and adds a
  code-side fallback that enables/programs the named `hdmi_tv` clock if the
  HDMI clock handle still reads as `0` or `24 MHz`.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`; the important diagnostic is whether
  `opi_logo_hdmi` remains present and gains a `tv49000000`-style value.
- Reboot result: Linux reached NVMe and diagnostics stayed present.
  `opi_logo_hdmi` included `tv49000000`, proving the named `hdmi_tv` fallback
  worked. The bootloader display stayed black because the low-level PHY/MC
  state was still not locked (`stat00`, `lock00`) before Linux reinitialized
  HDMI.

2026-07-03 HDMI TV clock plus TOP/MC parity diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk-topmc.fex`
- Package SHA-256:
  `9a71e37c0773a3b9d408d651db12037e7d7bbe5d7624244961f5610f38c89989`
- U-Boot item SHA-256:
  `bb53b2a56f12fb52d9db076890e1ac64adfb659a6ed2497acbb6e7ca25a4e21e`
- This package keeps the stock embedded U-Boot DTB and vendor monitor/SCP
  blobs. It combines the successful `hdmi_tv` fallback with Linux TOP PHY PLL
  auto-calculation, Linux-like MC clock enable order, normal-path TCON format
  propagation, and passive TOP PHY register diagnostics. It does not include
  the unsafe full DRM reinit command.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`; useful diagnostics are retained
  `tv49000000`, new `top20_` through `top40_` fields, and any movement of
  `stat`/`lock` toward Linux's locked HDMI PHY state.
- Reboot result: Linux reached NVMe and U-Boot retained diagnostics. TOP PHY
  registers now matched Linux's visible PLL words, including `top20_e8193000`
  and `top40_00000001`. The bootloader display stayed black because the
  DW/SNPS core still read `phy00,stat00,rst00,lock00,vid00,gcp00` before Linux
  later disabled/re-enabled HDMI and reached SNPS PHY lock.

2026-07-03 stale HDMI enable-state retry diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk-topmc-staleretry.fex`
- Package SHA-256:
  `d0d129a5718e0d8fb65f5c573ab793f67285988bf529a6361a6b763413e10658`
- U-Boot item SHA-256:
  `fe048ea27580f9248577f735380e40cbb31fd6893629285dbfa73b99581af1a5`
- This package treats a claimed-enabled but unlocked HDMI PHY as stale in
  `_sunxi_drv_hdmi_enable()`, clears it with `sunxi_hdmi_disconfig()`, then
  continues through the normal `sunxi_hdmi_config()` path. It also stops
  marking `drv_enable=1` when HDMI config fails.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`; the useful diagnostic is whether
  `opi_logo_hdmi` moves away from `phy00,stat00,rst00,lock00` before Linux.
- Reboot result: Linux reached NVMe and U-Boot diagnostics were retained, but
  the bootloader display stayed black. The cmdline still showed
  `phy00,stat00,rst00,lock00`, so the retry inside `_sunxi_drv_hdmi_enable()`
  did not run in the successful logo path. The likely reason is that
  `display_enable()` returned early because `state->is_enable` was already
  true.

2026-07-03 stale HDMI logo-path reinit diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk-topmc-logorecover.fex`
- Package SHA-256:
  `8e8926949c5453fd1590341a8489120a52bc2e52f3c35c9bf384994f8d928efd`
- U-Boot item SHA-256:
  `80f455d74201ac7209116b637851766532a4cfb516072894542c45bd1f38034a`
- This package keeps the successful stock-DTB, forced 1024x600, `hdmi_tv`
  fallback, TOP/MC parity, and stale low-level enable retry patches. It adds a
  narrower recovery in `sunxi_show_logo()` before `display_logo()`: if HDMI-A
  is marked initialized/enabled but the DW/SNPS PHY and MC lock registers are
  unlocked, U-Boot calls `display_disable()`, then `display_init()`, then lets
  the normal logo path draw and enable.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`. The new useful diagnostic is
  `opi_logo_recover=stale-reinit-d0-i0-p00-l00` or a similar code in
  `/proc/cmdline`, plus movement in `opi_logo_hdmi` away from
  `phy00,stat00,rst00,lock00`.

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

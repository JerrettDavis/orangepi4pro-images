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

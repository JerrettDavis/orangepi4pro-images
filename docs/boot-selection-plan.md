# Boot Selection Plan

Current status on 2026-07-04:

- The machine boots NVMe Ubuntu through extlinux.
- The active SD bootloader package is the vendor NVMe package:
  `/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package_a733_nvme.fex`,
  SHA-256
  `e626234a6eb9420ac29f515dd6acc543e7f0876e3dc086eec2fe221a50cc54f2`.
- The vendor NVMe package plus mirrored `bootlogo.bmp`, `boot.bmp`, and
  `boot1.bmp` still produced no visible bootloader splash or selector on the
  cyberdeck display. The reboot did reach NVMe through
  `bootchooser=extlinux-legacy-nvme`.
- The desktop startup error after that reboot was an apport report for
  `/usr/sbin/lightdm` from shutdown time (`/var/crash/_usr_sbin_lightdm.0.crash`);
  LightDM then restarted and autologin succeeded. Treat it as separate from
  bootloader-display progress unless it repeats with a new crash timestamp.
- The next bounded recovery-oriented test is to restore the stock vendor SD
  package, because Orange Pi's `platform_install.sh` writes
  `boot_package.fex` to SD media while the externally recovered slot currently
  contains `boot_package_a733_nvme.fex`. The SD `/boot/extlinux/extlinux.conf`
  still defaults to the NVMe root UUID, so this should preserve the NVMe boot
  while testing whether the factory SD package restores the visible
  "initializing boot loader" path.
- Result: restoring the stock vendor SD package
  (`boot_package.fex`, SHA-256
  `7a2661b080f5c5d8ba32566bc79f1ccfbfb8912a4a5c0c1a4856a9380542c807`)
  preserved reliable NVMe boot and restored the Ubuntu/Plymouth OS splash, but
  still did not show a bootloader splash. Because stock SD U-Boot scans
  extlinux before `boot.scr`, that test did not execute the staged
  `sunxi_show_logo` hold.
- Next test: install the stock SD U-Boot package with only the same-length
  script-first scan-order patch:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst.fex`,
  SHA-256
  `77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`.
  Live boot files are staged for `selector_logo_preinit=true`,
  `selector_logo_hold=20`, `selector_diag_force_bootm=true`, and
  `extlinux_first=false`, so this package should run the factory
  `sunxi_show_logo` path for a visible 20-second hold before booting NVMe.
- Result: Linux reported `bootchooser=uboot-logo-preinit-ok`, proving
  script-first U-Boot ran `/boot/boot.scr`, but there was still no visible
  bootloader splash. The diagnostic legacy `bootm` handoff also removed the
  Ubuntu/Plymouth OS splash. Restore `selector_diag_force_bootm=false` and
  `extlinux_first=true` for future visual tests unless a marker-preserving
  legacy path is explicitly needed.
- Source review showed the stock logo command does not load logo files from
  the extlinux `/boot` directory. It loads from named Allwinner partitions
  `bootloader` and `boot-resource`. The current SD card is a single DOS Linux
  partition, so there is no named `boot-resource` for that lookup. The next
  bounded hypothesis is a small guarded Allwinner boot-resource area in the
  zeroed reserved SDMMC logical window before the Linux partition, created by
  board-support `scripts/stage-sd-boot-resource.sh`.
- Result: installing the guarded `boot-resource` area did not make the
  bootloader splash visible. It did preserve the normal extlinux NVMe boot and
  Ubuntu/Plymouth splash. The next step is not another logo filename or
  resource-partition permutation; it is a source-side U-Boot diagnostic that
  records whether `load_bmp_logo()` and `display_logo()` succeeded before
  extlinux replaces the boot script's temporary environment.
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
- The current A733 U-Boot logo path hard-codes `bootlogo.bmp` in
  `drivers/video/sunxi/logo_display/cmd_sunxi_bmp.c::do_sunxi_logo()`, while
  the BootGUI/fast-logo code also contains `boot.bmp`/`boot1.bmp` fallback
  strings. The Orange Pi factory-style asset still exists as `/boot/logo.bmp`
  and `/boot/efi/logo.bmp`, but `bootlogo.bmp` was absent and `boot.bmp` /
  `boot1.bmp` had been replaced during selector tests.
- Stage the next test with:

```bash
sudo scripts/stage-factory-logo-preinit-test.sh \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

This restores `logo.bmp` to the filenames U-Boot actually loads
(`bootlogo.bmp`, `boot.bmp`, and `boot1.bmp`), runs `sunxi_show_logo`, holds
for 20 seconds, and then boots NVMe through the known-good legacy `bootm` path.
Expected Linux evidence is
`bootchooser=uboot-logo-preinit-ok` plus `opi_logo_*` HDMI diagnostics.

2026-07-04 recovered-stock bootloader state:

- After external recovery, the installed SD bootloader slot byte-matches the
  vendor NVMe package:
  `/usr/lib/linux-u-boot-current-orangepi4pro_1.0.6_arm64/boot_package_a733_nvme.fex`
  (`sha256=e626234a6eb9420ac29f515dd6acc543e7f0876e3dc086eec2fe221a50cc54f2`).
- `/dev/mtdblock0` reads as erased (`0xff` header), so the currently observed
  boot path is the SD raw bootloader slot, not SPI/MTD.
- The vendor NVMe package scans extlinux before boot scripts and reaches the
  NVMe entry with `bootchooser=extlinux-legacy-nvme`; therefore the immediate
  visual recovery test should not install another custom bootloader package.
  Restore `bootlogo.bmp` aliases first, keep extlinux as the selectable path,
  and only return to script-first U-Boot after the stock splash is visible.

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
- Reboot result: Linux reached NVMe and U-Boot diagnostics stayed present, but
  `opi_logo_recover` was absent and `opi_logo_hdmi` still reported
  `phy00,stat00,rst00,lock00`. The pre-logo stale check did not match the
  state at that point.

2026-07-03 post-logo HDMI lock retry diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk-topmc-postlogoretry.fex`
- Package SHA-256:
  `540e7a150ce0a7c74feed86da3c3c5efd3262c6c628ab4efb3942e15791fac0f`
- U-Boot item SHA-256:
  `f5f812a752f8dfb1674bf39c09e6130024d75498ffbf2a01db3392cbe30f4eab`
- This package keeps the previous logo-path recovery and adds a second check
  after `display_logo()` has drawn the BMP and called `display_enable()`. If
  HDMI-A is still marked enabled but the PHY/MC lock registers remain unset,
  U-Boot performs one `display_disable()`/`display_init()`/`display_enable()`
  retry and records `opi_logo_recover=post-retry-...`.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`. The important new signal is whether
  `/proc/cmdline` gains `opi_logo_recover=post-retry-...` and whether
  `opi_logo_hdmi` moves away from `phy00,stat00,rst00,lock00`.
- Reboot result: Linux reached NVMe and diagnostics stayed present, but
  `opi_logo_recover` was absent and `opi_logo_hdmi` still reported
  `phy00,stat00,rst00,lock00`. The next package removes the stricter state
  checks from the retry decision and records skip reasons.

2026-07-03 relaxed post-logo HDMI retry diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk-topmc-relaxedretry.fex`
- Package SHA-256:
  `4e0941a6eb25f7a9e40a7496dc6957eea43f533e636b85813ee972ae5bf7cf9a`
- U-Boot item SHA-256:
  `6337413c6991aed676e669e279db964e72163372626f84953a3e8c36e8a918bb`
- This package makes the post-logo check read `PHY_STAT0` and `MC_LOCKONCLOCK`
  directly. If lock is missing after `display_enable()`, it performs one
  disable/init/enable retry without requiring `state->is_enable` or a connector
  type match. It always records either `opi_logo_recover=post-retry-...`,
  `opi_logo_recover=post-skip-not-init`, or
  `opi_logo_recover=post-skip-locked`.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`. The important new signal is which
  `opi_logo_recover` value appears and whether `opi_logo_hdmi` moves away from
  `phy00,stat00,rst00,lock00`.
- Reboot result: Linux reached NVMe and
  `opi_logo_recover=post-skip-locked` appeared. U-Boot saw immediate lock after
  logo enable, but the bootloader display was still invisible and the later
  HDMI diagnostic still reported `phy00,stat00,rst00,lock00`.

2026-07-03 forced post-logo HDMI visible reinit diagnostic:

- Candidate package:
  `/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-scriptfirst-diag-modeclock-force1024-hdmitvclk-topmc-forcereinit.fex`
- Package SHA-256:
  `dac4949d4e5ad3fdb8c3db0bf16811f2ce8ed4948c242ffeebe3c052d940f7a1`
- U-Boot item SHA-256:
  `ca67510ad8e65130e29befbce2c0347e36fff1f8ecd6560bce3690f34d0e3087`
- This package forces one post-logo
  `display_disable()`/`display_init()`/`display_enable()` sequence even when
  U-Boot's immediate DW/SNPS lock bits look successful. It keeps the same
  `opi_logo_recover=post-retry-...` before/after register diagnostics.
- Expected post-reboot evidence remains
  `bootchooser=uboot-logo-preinit-ok`. The useful signal is
  `opi_logo_recover=post-retry-...`; the desired outcome is a visible
  bootloader splash/selector before Linux starts.
- Reboot result: unsafe. The board did not complete normal startup and required
  external SD recovery from another machine. After recovery the machine booted
  NVMe through `bootchooser=extlinux-legacy-nvme`, without the U-Boot
  `opi_logo_*` diagnostic path. Do not reinstall package SHA
  `dac4949d4e5ad3fdb8c3db0bf16811f2ce8ed4948c242ffeebe3c052d940f7a1`
  except for deliberate bench recovery testing.

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

## 2026-07-04 BootGUI Logo Command Test

The next reboot test keeps the installed SD TOC1 package unchanged:
`boot_package_vendor-sd-scriptfirst.fex`
(`77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`).
Only boot filesystem files are staged.

Rationale: the previous preinit tests exercised AW_DRM `sunxi_show_logo`.
Vendor source also exposes a separate BootGUI `logo` command that calls
`sunxi_bmp_display("bootlogo.bmp")`, which is a closer match to the factory
splash path.

Stage command:

```bash
sudo scripts/stage-bootgui-logo-test.sh \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

Expected Linux evidence after reboot is either
`bootchooser=uboot-bootgui-logo-ok` or
`bootchooser=uboot-bootgui-logo-fail`. The desired visual result is a visible
bootloader image during the 20-second hold before the NVMe Ubuntu boot.

Result: after both the synthetic `boot-resource` layout and the restored
reserved-window layout, Linux reached NVMe with
`bootchooser=uboot-bootgui-logo-fail` and no pre-OS bootloader image was
visible. The `logo` command path is not the active fix path.

The next staged test returns to the HDMI20 isolation path:

```bash
sudo scripts/stage-uboot-visual-test.sh \
  --test hdmi20_pattern \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

Expected evidence after reboot is
`bootchooser=uboot-visual-hdmi20-pattern-ok` or
`bootchooser=uboot-visual-hdmi20-pattern-fail`.

Result with the stock script-first package
`boot_package_vendor-sd-scriptfirst.fex`
(`77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670`):
Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-fail`. The diagnostic environment
showed `opi_pre_drm_diag=missing`, `opi_pre_hdmi=diag-missing`,
`opi_pat_hdmipat=unset`, `opi_post_drm_diag=missing`, and
`opi_post_hdmi=diag-missing`. That package preserves factory script-first
behavior but does not contain the `sunxi_hdmi20`, `sunxi_drm_env`, or
`sunxi_hdmi_env` commands needed for this isolation test.

The next reboot installs the previously safe diagnostic-capable package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-busclock-720p.fex
sha256=0a7a82b76e83cbb612c145c8f9414bb7dc7b4a5ce0c533c9cf002c4880337182
u-boot item sha256=50c3195cd076c8c8c3fedd596ecfc4fe034a505e7e50e8647b0a1acb426b622a
```

Safety/capability strings before install: contains `boot.scr`,
`sunxi_hdmi20`, `sunxi_drm_env`, `sunxi_hdmi_env`, `opi_hdmi_diag`, and
`opi_drm_diag`; does not contain `sunxi_drm reinit`. The SD TOC1 installer
backed up the previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T030311Z.bin`
and verified the readback byte-for-byte after writing. The same
`hdmi20_pattern` 20-second hold remains staged for the next boot.

Result: Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-fail`, but the package populated real
pre/post diagnostics instead of `missing` values:
`opi_pre_drm=...mode=1280x720,clk=74250...`,
`opi_pre_hdmi=fast1,hpd1,clk1,out1,drm1,mode1,...hdmi74250000,...toplock1...`,
and matching `opi_post_*` values. The remaining diagnostic gap is
`opi_pat_hdmipat=unset`, because this older bus-clock candidate does not export
the HDMI pattern status. No visible bootloader selector appeared before Linux.

The next reboot installs the pattern-status 1024x600 package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-patternstatus-1024x600.fex
sha256=2b79a35b9182a63a4304cb89aa1b1178fe214abe03050923b212a06e05a24abd
u-boot item sha256=63d7076c480805e6dbead46548ef1191c616337743ca9798c0f15afa29c57302
```

Safety/capability strings before install: contains `boot.scr`,
`sunxi_hdmi20`, `sunxi_drm_env`, `sunxi_hdmi_env`,
`opi_hdmi_pattern_diag`, `opi_hdmi_diag`, and `1024x600`; does not contain
`sunxi_drm reinit` or `full hdmi reinit`. The SD TOC1 installer backed up the
previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T031045Z.bin`
and verified the new slot by readback. The same `hdmi20_pattern` 20-second
hold remains staged.

Result: Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-ok`. The useful new marker is
`opi_pat_hdmipat=req1,tcon0,force01,rff,g00,b00`; U-Boot reports that the
HDMI20 frame composer accepted the forced red pattern at the Linux-working
`1024x600`/49 MHz timing. If the screen still stayed black before Linux, the
next test is the bounded pattern reconfigure package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-pattern-reconfig-1024x600.fex
sha256=5e1e7209d7fe8535c998c640593f280a6b8f94f7afc4115cb11218189687d92d
u-boot item sha256=56e9e8e882485333850f928920f0d79914e0fd36b8f5a7af8ff2099301bae972
```

Safety/capability strings before install: contains `boot.scr`,
`sunxi_hdmi20`, `sunxi_drm_env`, `sunxi_hdmi_env`,
`opi_hdmi_pattern_diag`, `opi_hdmi_pattern_reconfig`, `opi_hdmi_diag`, and
`1024x600`; does not contain `sunxi_drm reinit` or `full hdmi reinit`.
The SD TOC1 installer backed up the previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T031632Z.bin`
and verified the new slot by readback.
Expected evidence after reboot is
`opi_pat_hdmipat=req1,reconfig0,...`.

Result: Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-ok` and
`opi_pat_hdmipat=req1,reconfig0,tcon0,force01,rff,g00,b00`. The bounded HDMI
reconfigure returned success, but direct DesignWare HDMI core diagnostics were
still zero in `opi_pre_hdmi` and `opi_post_hdmi`:
`phy00,stat00,rst00,lock00,vid00,gcp00`. If the screen remained black before
Linux, the next test is the frame-composer iteration package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-fciter-1024x600.fex
sha256=a6ff4344d16002f4274a30fee0c4ed861fb6e4e1cedd9251a810ab38e69a2db0
u-boot item sha256=531c73cf5f7ace30e2dfba95e52a0beaa3beccf830984f92d5a259649967e556
```

This package carries
`configs/u-boot/0019-sync-linux-hdmi-fc-iteration-and-diag.patch`, which adds
Linux's missing frame-composer iteration write and reads the DesignWare
registers without the stale `sw_init` guard. It does not contain
`sunxi_drm reinit` or `full hdmi reinit`. The SD TOC1 installer backed up the
previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T031946Z.bin`
and verified the new slot by readback.

Result: Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-ok`. The FC-iteration package changed
the direct HDMI core diagnostics from all-zero to
`phy2e,stat03,rst00,lock70,vid58,gcp01` and recorded
`opi_reinit_reinit=...core2e0300705801`. The remaining likely gap is RX-sense:
U-Boot still reports `stat03`, while later Linux HDMI visibility has shown
upper RX-sense lane bits. The next test is the bounded RX-sense wait package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-rxsense-1024x600.fex
sha256=59fe28f8c629ff194e413cc7dd2878c6a6aec7103744a0422a4a1c537576d3ff
u-boot item sha256=1f0cd3409f43a11909f3b18f199554258c69b434332bbd8bf61e6fa05c07498b
```

This package carries
`configs/u-boot/0020-wait-for-snps-phy-rxsense.patch`. It contains the same
HDMI20 diagnostic commands plus `rxsense`, and does not contain
`sunxi_drm reinit` or `full hdmi reinit`. The SD TOC1 installer backed up the
previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T032239Z.bin`
and verified the new slot by readback.

Result: Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-ok`, but `PHY_STAT0` did not move
toward the later Linux-visible RX-sense state. HDMI diagnostics stayed at
`phy2e,stat03,rst00,lock70,vid58,gcp01`. The next forward test is the
MC-clock package, which adds top-PHY PLL diagnostics/autocal and the Linux-like
main-controller clock sequencing:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-mcclk-1024x600.fex
sha256=4d15d7c88b17aa1114aa99175ad489a4d3a36142430736fda2a4b113cb1e1844
u-boot item sha256=4febc8f1543f071fd12d63949e3ca7a79f7b030c7668c212029221c17cce46c1
```

Expected evidence: `opi_pre_hdmi`/`opi_post_hdmi` should include
`top20_...top40_...`, and `MC_LOCKONCLOCK` should show whether the main
controller moved from `lock70` toward Linux's visible `lock79`. The SD TOC1
installer backed up the previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T032623Z.bin`
and verified the new slot by readback.

Result: Linux reached NVMe with
`bootchooser=uboot-visual-hdmi20-pattern-ok`. The top-PHY PLL fields now
matched the Linux values (`top20_e8193000`, `top24_00000080`,
`top40_00000001`), but the HDMI core still reported
`phy2e,stat03,rst00,lock70,vid58,gcp01`. The next test is the TCON-format
package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-hdmi-tconfmt-1024x600.fex
sha256=1476e41aeae6bfeff49128146bfc5515beb03e3e2d83fad4c41bdf8d60ed6dec
u-boot item sha256=21b1fe5b5d03709d840b024d0d15ec96fe99a7e469c96189ed660a01b178fa5c
```

This package carries
`configs/u-boot/0024-pass-hdmi-format-to-tcon-reinit.patch`, adding
`fmt`/`sw` diagnostics to `opi_reinit_reinit` and passing the HDMI format into
TCON init. It does not contain `sunxi_drm reinit` or `full hdmi reinit`. The
SD TOC1 installer backed up the previous slot to
`/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T032919Z.bin`
and verified the new slot by readback.

2026-07-04 raw DE/TCON diagnostic stage:

The current staged visual test remains:

```bash
scripts/stage-uboot-visual-test.sh \
  --test hdmi20_pattern \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

The generated boot script now calls `sunxi_de_env` after the HDMI pattern test
and appends only the post-test DE/TCON snapshot as `opi_post_de=...`. This
keeps the kernel command line bounded while capturing the first data that can
distinguish an HDMI-link success from a DE/TCON scanout failure.

The installed SD TOC1 package for the next reboot is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-de-diag-hdmi-pattern-1024x600.fex
sha256=969e19b6a3e231f7e65b686bbc5dfa07b6e7d37df6decefdf88f214cc9bf535b
u-boot item sha256=38ae59c77939ac73c06983b3e467aa3ee978b0ed05c0e211e077a5fe07f985a2
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T040742Z.bin
sha256=0e9404b729eb5114b6058dca6a093c3d2861bc5b2e8077285b3dc52162895b54
```

Expected evidence after reboot is
`bootchooser=uboot-visual-hdmi20-pattern-ok` plus `opi_post_de=...`. If the
screen is still black before Linux, compare those U-Boot DE/TCON register
groups against the Linux DRM/TCON state that becomes visible after the kernel
mode set.

Result: Linux reached NVMe and recorded `opi_post_de=...`, but the initial raw
diagnostic sampled TCON4 only. The packaged U-Boot DTB routes HDMI through
`tcon3@5730000`; `tcon4@5731000` is the EDP path. Linux live register reads
after the visible mode set showed active TCON3 values at `0x05730000` offsets
`0x000`, `0x004`, `0x088`, `0x08c`, `0x090`, `0x098`, `0x09c`, `0x0a0`,
`0x0a4`, `0x0a8`, and `0x0fc`.

2026-07-04 corrected TCON3 diagnostic stage:

The boot assets remain staged as:

```bash
scripts/stage-uboot-visual-test.sh \
  --test hdmi20_pattern \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

The installed SD TOC1 package for the next reboot is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-tcon3diag-hdmi-pattern-1024x600.fex
sha256=0381eff0a7a65ee407856b6ec9a10e4a0c82c8a4c3aa64f4f008b4b26024293f
u-boot item sha256=92334f2f929e1c8867902081c64a0335cd984be3c1189899c8500d8541a4ebb7
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T041753Z.bin
sha256=7188d42ff484a2c9ee7d9318ccae78bdb266c19438358c3a1cb710315c9e6a4a
```

Expected evidence after reboot is
`bootchooser=uboot-visual-hdmi20-pattern-ok` plus `opi_post_de=...t3=...`.
This is still a bootloader-stage test; no userland selector fallback is part of
the target path.

2026-07-04 RX-sense stale-HDMI bootmenu package:

Live Linux-visible register reads showed that visible HDMI output has
`PHY_STAT0=0xf3`, `MC_LOCKONCLOCK=0x79`, and `FC_PACKET_TX_EN=0x1f`. The last
U-Boot package reached Linux with `stat03` and `lock70`; U-Boot considered that
locked, but the RX-sense bits were absent. The current test tightens the
stale-HDMI checks so U-Boot does not skip reconfiguration unless all RX-sense
bits are also present.

The staged visual test remains:

```bash
scripts/stage-uboot-visual-test.sh \
  --test hdmi20_pattern \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

The installed SD TOC1 package for the next reboot is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_a733-custom-bootmenu-rxsense-stale-retry-hdmi-pattern-1024x600.fex
sha256=feacc7a99a48a1f6a64318b8372042f0b24df36bc5bae1f35f4bcc36581e6438
u-boot item sha256=dc8fabad16732d543f76b584e211b02e741eb4f0cdbbff4db9887a35517e3975
build artifact sha256=9e289fab52d09d76f967b2e664765500f33ebc1d06003982b9eff920858550d4
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T043036Z.bin
sha256=d8dcda3f1f422f972d57cd761bcd3c179c42ef5c218e629179a7c2d161dfb2ef
```

Expected evidence after reboot is still
`bootchooser=uboot-visual-hdmi20-pattern-ok`. The useful new evidence is whether
`opi_pre_hdmi`/`opi_post_hdmi` advance from `stat03` toward `statf3`, or whether
`opi_logo_recover` reports a stale retry path. The visual target remains a
bootloader-stage image before Linux starts.

Actual result: unsafe. The board did not complete a normal boot and required
external WSL recovery. After recovery it booted NVMe with
`bootchooser=extlinux-legacy-nvme`, so the RX-sense package did not leave useful
U-Boot visual diagnostics in `/proc/cmdline`. The package SHA
`feacc7a99a48a1f6a64318b8372042f0b24df36bc5bae1f35f4bcc36581e6438` is now
blocked by the SD installer and settlement gate.

2026-07-04 delayed factory-logo bootloader test:

The next bootloader-stage test returns to the vendor embedded-logo path and
adds only a 5-second delay inside AW_DRM `sunxi_show_logo()`. This is based on
the observed gap between early U-Boot display bring-up and Linux's later
successful HDMI configuration.

The staged boot assets are:

```bash
scripts/stage-extlinux-prompt-selector.sh \
  --timeout 200 \
  --default ubuntu-nvme \
  --video-console false \
  --selector-bitmap false \
  --logo-preinit true \
  --logo-command sunxi_show_logo \
  --logo-hold 15 \
  --extlinux-first true \
  --diag-force-bootm false \
  --sd-boot-dir /mnt/opisd-rw/boot
```

The SD TOC1 package for the next reboot is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_nvme-scriptfirst-sunxi-show-logo-delay.fex
sha256=65eaba1bff9c98324213d0a6c4849f2dccf74de2b115e4edb724ed63a29e6012
u-boot item sha256=e10c6eab23b27993cfbdd65c85afac1bc16d4e5570ed4ed57f43ddb3bec84f55
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T164212Z.bin
sha256=513388dd8c9ee53412ea2742427550c97c1a929144c8a681afd4da63cdded2be
```

Readback validation confirmed the installed SD TOC1 slot byte-matches package
SHA `65eaba1bff9c98324213d0a6c4849f2dccf74de2b115e4edb724ed63a29e6012`.

Expected evidence after reboot is a visible vendor bootloader logo during the
15-second hold, followed by NVMe Ubuntu with `bootchooser=uboot-logo-preinit-ok`
or `bootchooser=extlinux-legacy-nvme` depending on whether the script path
exports the marker before extlinux takes over.

Actual result: failed visually. The system booted NVMe Ubuntu, but the screen
stayed black/no-signal until Linux/desktop. `/proc/cmdline` reported
`bootchooser=extlinux-legacy-nvme`; that extlinux path does not preserve the
U-Boot logo diagnostics.

2026-07-04 delayed factory-logo diagnostic boot:

The next test keeps the delayed vendor embedded-logo path but adds passive
U-Boot DRM/HDMI env diagnostics and forces the marker-preserving bootm path for
one reboot. This is still bootloader-stage work; it is not a userland selector.

The staged boot assets are:

```bash
scripts/stage-extlinux-prompt-selector.sh \
  --timeout 200 \
  --default ubuntu-nvme \
  --video-console false \
  --selector-bitmap false \
  --logo-preinit true \
  --logo-command sunxi_show_logo \
  --logo-hold 15 \
  --extlinux-first true \
  --diag-force-bootm true \
  --sd-boot-dir /mnt/opisd-rw/boot
```

The SD TOC1 package for the next reboot is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_nvme-scriptfirst-logo-delay-diag.fex
sha256=17c107db643f858b289e600abed5ad9aee3edd0949f1a2a7fb381bebd07caf2a
u-boot item sha256=b6d35454586a5bb634fd9a899d567837b106493be04d7273e73b9f51beb39466
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T165041Z.bin
sha256=f0ba7e5ca7c0d40acd12b1986ffcf00e0041cf1b0f9c7c78639e5e3a523f5de9
```

Readback validation confirmed the installed SD TOC1 slot byte-matches package
SHA `17c107db643f858b289e600abed5ad9aee3edd0949f1a2a7fb381bebd07caf2a`.

Expected evidence after reboot is either visible bootloader output or, if the
screen remains black, a marker-preserved command line containing
`bootchooser=uboot-logo-preinit-ok`, `opi_logo_hdmi=...`, and
`opi_logo_drm=...`.

Actual result: failed visually but captured diagnostics. The boot reached NVMe
Ubuntu and `/proc/cmdline` preserved the U-Boot markers. U-Boot reported HDMI-A
initialized and enabled at 1920x1080, but HDMI low-level status was still idle:
`hdmi24000000`, `phy00`, `stat00`, `rst00`, and `lock00`.

2026-07-04 fixed U-Boot spare-header diagnostic boot:

The previous package exposed a build-system defect: the vendor
`scripts/sunxi_ubootools` binary is x86-64-only and does not run on the ARM
board, so rebuilt U-Boot binaries had zeroed spare-header `length` and
`uboot_length` fields. The new board-support helper
`scripts/fix-sunxi-uboot-header.py` pads, fills, and verifies those fields after
build.

The next SD TOC1 package for reboot testing is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_nvme-logo-delay-diag-fixed-header.fex
sha256=eae2651699fa2c14556124f68dbc33f9d9c8dd298f0ee41574582f7a531e713e
u-boot item sha256=592231881302f90524aa9c36bdb134335283fc3b266b42f97f787b3cdde0bce5
```

This package keeps the same passive delayed-logo diagnostics as the previous
test. The only intended behavioral difference is valid U-Boot spare-header
metadata.

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T171105Z.bin
sha256=17c2cb8ba2ffcdca5ecca9b15741afa0091ebc5673dc35a9eb67b77e3dbe77ec
```

Readback validation confirmed the installed SD TOC1 slot byte-matches package
SHA `eae2651699fa2c14556124f68dbc33f9d9c8dd298f0ee41574582f7a531e713e`.

Actual result: failed visually. The board booted NVMe Ubuntu and preserved the
U-Boot diagnostic marker, but HDMI diagnostics were unchanged: U-Boot reported
HDMI-A initialized/enabled at 1920x1080 while the low-level HDMI status stayed
idle/unlocked.

2026-07-04 stock vendor U-Boot visual recovery test:

The next test stops using locally rebuilt U-Boot for display. It returns to the
stock Orange Pi NVMe U-Boot item, which is the only payload known to have shown
the factory "initializing boot loader" splash on this hardware. The only U-Boot
payload change is the length-preserving scan-order replacement from
extlinux-first to script-first.

The installed SD TOC1 package is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-nvme-scriptfirst-stockvisual.fex
sha256=d798104ccd705e542842fac409b1e2694c6ca19fcfac75fc30036a4535a7d318
u-boot item sha256=77836181cc87b84559b11579eeb8388f216c51b8127951e2692a92101be6ace0
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T171807Z.bin
sha256=03bec02a59c88366e22d6350a9b01979049acd5f722c859877e881f27b6719f6
```

Settlement validation confirmed the installed SD TOC1 slot byte-matches package
SHA `d798104ccd705e542842fac409b1e2694c6ca19fcfac75fc30036a4535a7d318`.

Expected evidence after reboot is the factory bootloader splash returning
before the OS loader. This is not yet the final selector; it is the display
recovery step needed before adding selection interaction on top of the stock
display path.

Actual result: failed visually. The board booted NVMe Ubuntu and preserved
`bootchooser=uboot-logo-preinit-ok`, but because this was stock U-Boot the
custom HDMI/DRM diagnostics were unavailable (`diag-missing`).

2026-07-04 SD boot-resource restore:

The stock-U-Boot test proved that the TOC1 U-Boot item alone is not enough to
recover the factory splash. The reserved SD boot-resource area at sectors
40960-65536 was read back as all zeroes. Boot0 still matches stock, and the
stock U-Boot package is installed, so the next test restores the Allwinner
boot-resource MBR/FAT area and its logo files.

The restore command was:

```bash
ORANGEPI4PRO_ALLOW_BOOT_RESOURCE_WRITE=1 \
  /home/orangepi/orangepi4pro-board-support/scripts/stage-sd-boot-resource.sh \
  --device /dev/mmcblk1 \
  --source-logo /boot/logo.bmp \
  --yes
```

The restore backed up the previous reserved range to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-boot-resource-before-20260704T172145Z.bin
sha256=cfadd44a103cbd6d5726fa07b27d7aad2f67ed3930ff96901c486a5beaf7e723
```

Readback validation now passes:

```text
softw411 boot-resource MBR validation passed
SD boot-resource validation passed
mbr sha256=cc62563f96ec00f80c3bfd5464271fca18eaa174c7ad7dd7d4498e97f3c11620
fat sha256=74d3006381d0b20b68c963774d3e1584d3d45fb32d03e2e294b5a7e28efe2b07
logo sha256=96739ee09e816d9428becc0b2150a141929bab997f7dccbe82b4af2c5427c0d5
```

Settlement validation now includes this boot-resource check. Expected evidence
after reboot is the factory bootloader splash returning before the OS loader.

Actual result: failed visually. The restored boot-resource area survived and
validates after reboot, but the HDMI display still stayed black before Linux.

2026-07-04 stock U-Boot colorbar visual test:

Stock U-Boot has no `bootmenu`, so the final selector cannot come from its
built-in text menu. It does include `sunxi_drm colorbar`, which is the next
bounded bootloader-stage visual test. The staged boot files now skip extlinux,
run `sunxi_drm colorbar 1`, hold for 20 seconds, and boot NVMe via legacy
`bootm`.

The staged command was:

```bash
/home/orangepi/orangepi4pro-images/scripts/stage-uboot-visual-test.sh \
  --test colorbar \
  --hold 20 \
  --sd-boot-dir /mnt/opisd-rw/boot
```

Expected evidence after reboot is a 20-second U-Boot colorbar before Linux,
followed by NVMe Ubuntu with `bootchooser=uboot-visual-colorbar-ok` or
`bootchooser=uboot-visual-colorbar-fail`.

Actual result: the U-Boot branch ran and returned success, but the HDMI display
still stayed black before Linux. `/proc/cmdline` contained
`bootchooser=uboot-visual-colorbar-ok`.

2026-07-04 stock SD factory U-Boot package test:

The previous tests used the vendor NVMe package
`boot_package_a733_nvme.fex`. The original visible factory splash may have
come from the standard SD package, so the next test installs
`boot_package.fex` with only the length-preserving script-first scan-order
patch. The staged boot files still run `sunxi_drm colorbar 1` for 20 seconds
and then boot NVMe through legacy `bootm`.

The installed package is:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_vendor-sd-scriptfirst-stockvisual.fex
sha256=77ef94aee8f8a6ec27d130822b70187fbf4316773d7ae5d59150e9027c654670
u-boot item sha256=94e5aa1cdebde42ce773f8d476fe78891cc61ad7e9e839d2554d738a549d55f5
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T172937Z.bin
sha256=49406a05fef3291f0e2320460e4a937ee50f098c916e987795e4cef51f4c07f1
```

Expected evidence after reboot is a visible factory splash or 20-second
colorbar before Linux, followed by NVMe Ubuntu with
`bootchooser=uboot-visual-colorbar-ok`.

Actual result: U-Boot again executed `sunxi_drm colorbar 1` and returned
success, but HDMI stayed black before Linux. `/proc/cmdline` contained
`bootchooser=uboot-visual-colorbar-ok`.

2026-07-04 stock SD U-Boot vidconsole plus colorbar test:

The next test keeps the stock SD factory script-first U-Boot package installed
and forces U-Boot video console output before colorbar. The staged boot script
sets `stdout=serial,vidconsole`, `stderr=serial,vidconsole`,
`stdin=serial,usbkbd`, runs `cls`, prints a console-active line, runs
`sunxi_drm colorbar 1`, holds for 20 seconds, then boots NVMe via legacy
`bootm`.

Staged environment on NVMe, EFI, and SD boot files:

```text
selector_console=true
selector_visual_test=colorbar
selector_visual_hold=20
extlinux_first=false
selector_logo_preinit=false
selector_diag_force_bootm=false
```

Expected evidence after reboot is visible U-Boot console text and/or the
20-second colorbar before Linux, followed by NVMe Ubuntu with
`bootchooser=uboot-visual-colorbar-ok`.

Actual result: failed visually. The system reached NVMe Ubuntu, but the screen
remained black until the OS loader/desktop.

2026-07-04 early display-init delay test:

The next installed package moves the wait earlier than `boot.scr`: it delays
for 8 seconds immediately before vendor U-Boot calls `initr_sunxi_display()`.
This tests whether the HDMI panel/bridge is not ready when AW DRM first
captures display state.

Installed package:

```text
/var/cache/orangepi4pro-images/build/boot-package-candidates/boot_package_sd-early-display-delay.fex
sha256=4fd435271d169f0d03e604551e98dd669b23ce570983914289e55152e9e6983a
u-boot item sha256=b1a7955133f03bd3676477292983c2f3d3c37d92278969d8f4b1efa4c9707665
```

Source:

```text
https://github.com/orangepi-xunlong/u-boot-orangepi.git
branch=v2018.05-sun60iw2
commit=b791be842935b27268ae3d00e943a9075495f30a
patch=configs/u-boot/0034-delay-before-sunxi-display-init.patch
```

The installer backed up the previous SD TOC1 slot to:

```text
/var/cache/orangepi4pro-images/bootloader-backups/mmcblk1-bootloader-before-20260704T174624Z.bin
sha256=e57b167478c264215ff81e52fd66fd75701f392a9c016b7408f12f174f879f0e
```

The staged boot files are unchanged from the last visual test:

```text
selector_console=true
selector_visual_test=colorbar
selector_visual_hold=20
extlinux_first=false
selector_logo_preinit=false
selector_diag_force_bootm=false
```

Expected evidence after reboot is visible pre-Linux U-Boot output during the
early delay and/or the 20-second colorbar hold, followed by NVMe Ubuntu with
`bootchooser=uboot-visual-colorbar-ok`. This package includes passive
`sunxi_drm_env` and `sunxi_hdmi_env`, so `/proc/cmdline` should include real
`opi_pre_*` / `opi_post_*` diagnostics instead of `diag-missing`.

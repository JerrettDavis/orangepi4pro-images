# Changelog

## 0.1.0 - 2026-07-02

- Created image-build repo.
- Recorded the actual NVMe GPT/filesystem layout.
- Documented the NVMe-primary live clone and successful vendor legacy `bootm`
  boot path.
- Added dry-run Ubuntu/Kali/rootfs/kernel/boot scripts plus NVMe validation
  helpers.
- Added CI checks for shell syntax, optional ShellCheck, secret patterns, and
  committed binary artifacts.

## Unreleased

- Staged GRUB ARM64 EFI assets and a hand-authored GRUB menu for NVMe Ubuntu and
  SD Ubuntu.
- Added an extlinux menu with the same Ubuntu entries because vendor U-Boot
  advertises `sysboot/extlinux` but not clear `bootefi` support.
- Updated `/boot/boot.cmd` order to try GRUB EFI, then extlinux, then legacy
  `bootm` fallback.
- Reboot-tested GRUB EFI, extlinux, and direct `booti`; all fell through to
  legacy `bootm`, so the probes are disabled by default in `orangepiEnv.txt`.
- Reviewed vendor U-Boot source and changed the extlinux menu to use legacy
  `uImage`/`uInitrd` entries so the PXE/extlinux code can dispatch through the
  working `bootm` path.
- Corrected the extlinux probe to match vendor distro boot syntax with
  partition-qualified `sysboot -p` and relative PXE asset paths, and added a
  `bootchooser=legacy-bootm-fallback` marker to the fallback path.
- Confirmed that the inserted SD card remains the active U-Boot script source
  even while Linux mounts NVMe as root; installed the corrected extlinux assets
  on the SD `/boot` path and added active boot-source validation.
- Corrected extlinux asset paths to parent-relative `../uImage...` form after
  confirming vendor `sysboot` resolves label files relative to `extlinux.conf`.
- Confirmed extlinux boots the NVMe entry and added a pre-menu pause plus a
  longer selector timeout for better visibility on HDMI.
- Added committed boot selector templates and an installer for reproducing the
  live `/boot`, `/boot/efi`, and active SD boot-source state.

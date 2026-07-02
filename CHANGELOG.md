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

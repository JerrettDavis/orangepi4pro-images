# Actual NVMe Layout

Created on 2026-07-02 on the Orange Pi 4 Pro A733 system.

Disk:

- Device: `/dev/nvme0n1`
- Model: `Fanxiang S500Pro 256GB`
- Serial: `[redacted hardware serial]`
- Size: 238.5 GiB

Mount base:

- `/mnt/orangepi4pro-m2`

| Part | Label | UUID | FS | Size | Mount point |
| --- | --- | --- | --- | ---: | --- |
| p1 | `OPI_EFI` | `C923-6E30` | vfat | 512 MiB | `/mnt/orangepi4pro-m2/efi` |
| p2 | `OPI_BOOT` | `fa64dd02-6cd1-4d70-9d1d-88bdbdc3333b` | ext4 | 2 GiB | `/mnt/orangepi4pro-m2/boot` |
| p3 | `UBUNTU_ROOT` | `eb86cfeb-60c7-4513-bc69-f6d28e9d561b` | ext4 | 50 GiB | `/mnt/orangepi4pro-m2/ubuntu-root` |
| p4 | `KALI_ROOT` | `efc7f3be-3c5d-4440-a107-33168629882c` | ext4 | 45 GiB | `/mnt/orangepi4pro-m2/kali-root` |
| p5 | `TOOLS` | `b491343e-59c0-4048-95e2-e292cdcf8c97` | ext4 | 24 GiB | `/mnt/orangepi4pro-m2/tools` |
| p6 | `HOME` | `7317da29-f743-4342-a297-3f0194262e8f` | ext4 | 32 GiB | `/mnt/orangepi4pro-m2/home` |
| p7 | `RESCUE_OR_ARCH` | `e9f5a50f-d5e9-4600-a0c8-bd56d280f35d` | ext4 | 32 GiB | `/mnt/orangepi4pro-m2/rescue-or-arch` |
| p8 | `IMAGES_CACHE` | `480c30b7-1e73-483d-9759-605f29dcd82d` | ext4 | 53 GiB | `/mnt/orangepi4pro-m2/images-cache` |

Ownership:

- Root-owned: `efi`, `boot`, `ubuntu-root`, `kali-root`, `rescue-or-arch`.
- `orangepi:orangepi`: `tools`, `home`, `images-cache`.

No bootloader sectors, SPI flash, SD bootloader area, or OS rootfs install was
written during this step.


# SD NVMe-First Loader

Prepared on 2026-07-02.

The live SD card is not EFI-booted and does not expose a PC-style GRUB
`BootOrder`. The current Orange Pi image uses a vendor U-Boot legacy script:

```text
/boot/boot.scr
/boot/boot.cmd
```

To make the NVMe install preferred while the SD card is still inserted, the SD
`/boot/boot.cmd` now tries the prepared NVMe boot partition first:

```text
nvme 0:2 boot.scr
```

If that script is loaded, the SD loader sets:

```text
devtype=nvme
devnum=0
prefix=
```

and sources the NVMe `boot.scr`. The NVMe script then loads its own
`orangepiEnv.txt`, `uImage`, `uInitrd`, and DTB.

If the NVMe script is not loaded, the SD script falls through to the original
stock SD boot flow.

## Backups

The original SD boot files were preserved with a UTC timestamp:

```text
/boot/boot.cmd.sd-original-20260702T024525Z
/boot/boot.scr.sd-original-20260702T024525Z
```

## Restore SD-Only Boot

From the running SD system or from another Linux system mounting the SD root:

```bash
sudo cp -a /boot/boot.cmd.sd-original-20260702T024525Z /boot/boot.cmd
sudo cp -a /boot/boot.scr.sd-original-20260702T024525Z /boot/boot.scr
sync
```

No SPI flash, MTD device, U-Boot environment sector, or NVMe bootloader sector
was modified.

## GRUB Status

GRUB can be staged later as an EFI artifact under `OPI_EFI`, but it will not
control boot priority unless the board firmware/U-Boot is confirmed to support
EFI boot manager variables or `bootefi` scanning from NVMe. The working control
point today is the legacy U-Boot script path.

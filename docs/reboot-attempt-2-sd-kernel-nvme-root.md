# Reboot Attempt 2: SD Loads Kernel, NVMe Root

Prepared on 2026-07-02 after the SD NVMe-first chainload attempt fell back to
the stock SD system.

## Result Of Attempt 1

After reboot, the system was still on SD:

```text
hostname: orangepi4pro
kernel: 5.15.147-sun60iw2
root: /dev/mmcblk1p1
root UUID: dc683cb4-0847-4d2f-83f1-184d35749d4c
```

Linux saw the NVMe drive, but U-Boot did not successfully source
`nvme 0:2 boot.scr` before falling back to SD.

## Attempt 2 Strategy

Use the SD card only as the U-Boot-readable boot filesystem, but load the
cyberdeck kernel/initrd/DTB from SD and mount the NVMe Ubuntu root.

SD `/boot` now points at:

```text
uImage -> uImage-5.15.147-sun60iw2-cyberdeck
uInitrd -> uInitrd-5.15.147-sun60iw2-cyberdeck
dtb -> dtb-5.15.147-sun60iw2-cyberdeck
```

SD `/boot/orangepiEnv.txt` now contains:

```text
rootdev=UUID=eb86cfeb-60c7-4513-bc69-f6d28e9d561b
rootfstype=ext4
```

Expected successful boot:

```text
hostname: opi4pro-nvme-cyberdeck
kernel: 5.15.147-sun60iw2-cyberdeck
root UUID: eb86cfeb-60c7-4513-bc69-f6d28e9d561b
```

This does not prove SD-less boot. It proves the patched kernel and NVMe root can
run while preserving the SD as the current firmware/U-Boot boot medium.

## Backup

Previous SD boot files were backed up to:

```text
/boot/backups/pre-sd-loads-nvme-root-20260702T025712Z
```

Restore SD-only kernel/root from a working SD boot:

```bash
sudo cp -a /boot/backups/pre-sd-loads-nvme-root-20260702T025712Z/orangepiEnv.txt /boot/orangepiEnv.txt
sudo cp -a /boot/backups/pre-sd-loads-nvme-root-20260702T025712Z/uImage /boot/uImage
sudo cp -a /boot/backups/pre-sd-loads-nvme-root-20260702T025712Z/uInitrd /boot/uInitrd
sudo rm -f /boot/dtb
sudo cp -a /boot/backups/pre-sd-loads-nvme-root-20260702T025712Z/dtb /boot/dtb
sync
```

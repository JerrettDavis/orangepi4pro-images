# Extlinux Default Repair

Observed on 2026-07-02:

```text
hostname: orangepi4pro
kernel: 5.15.147-sun60iw2
root UUID: dc683cb4-0847-4d2f-83f1-184d35749d4c
cmdline marker: bootchooser=extlinux-legacy-sd
```

That means U-Boot reached `extlinux.conf`, but the extlinux timeout selected
the SD entry.

Root cause:

```text
DEFAULT ubuntu-sd
```

Fix applied to SD `/boot/extlinux/extlinux.conf`, NVMe `OPI_BOOT`, and the
`OPI_EFI` fallback mirror:

```text
PROMPT 0
TIMEOUT 30
DEFAULT ubuntu-nvme
```

The SD entry remains available as `ubuntu-sd` for manual recovery, but timeout
now selects the NVMe Ubuntu root with the cyberdeck kernel.

Live SD backup:

```text
/boot/backups/pre-extlinux-default-nvme-20260702T054218Z
```

NVMe boot-partition backup:

```text
/mnt/orangepi4pro-m2/boot/backups/pre-extlinux-default-nvme-20260702T054302Z
```

Helper:

```bash
scripts/set-extlinux-default.sh ubuntu-nvme
sudo scripts/set-extlinux-default.sh --apply ubuntu-nvme
```

Post-reboot success check:

```bash
hostname
uname -r
findmnt -no SOURCE,FSTYPE,UUID /
cat /proc/cmdline
```

Expected:

```text
hostname: opi4pro-nvme-cyberdeck
kernel: 5.15.147-sun60iw2-cyberdeck
root UUID: eb86cfeb-60c7-4513-bc69-f6d28e9d561b
cmdline marker: bootchooser=extlinux-legacy-nvme
```

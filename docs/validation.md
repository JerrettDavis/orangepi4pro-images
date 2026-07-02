# Image Validation

Before install:

```bash
scripts/validate-target-disk.sh /dev/nvme0n1
scripts/mk-partitions.sh /dev/nvme0n1
```

After a future M.2 boot, use:

```bash
../orangepi4pro-cyberdeck/scripts/validate-future-m2.sh
```

For the current NVMe-primary baseline, also run:

```bash
scripts/validate-nvme-cyberdeck-kernel.sh /
```

For the prepared cyberdeck kernel on the mounted NVMe target, use:

```bash
scripts/validate-nvme-cyberdeck-kernel.sh /mnt/orangepi4pro-m2
```

For the SD NVMe-first loader, confirm:

```bash
file /boot/boot.scr
sed -n '1,40p' /boot/boot.cmd
ls -l /boot/boot.cmd.sd-original-* /boot/boot.scr.sd-original-*
```

For the reboot resume checklist, see:

```text
docs/reboot-resume-2026-07-02.md
```

For the second boot attempt using SD boot files with NVMe root, see:

```text
docs/reboot-attempt-2-sd-kernel-nvme-root.md
```

After the first NVMe boot, expected checks:

```bash
uname -r
zgrep -E 'CONFIG_(HID_MULTITOUCH|HIDRAW|UHID|INPUT_UINPUT)=' /proc/config.gz
lsmod | grep -E 'hid_multitouch|uhid|uinput'
libinput list-devices
onboard &
```

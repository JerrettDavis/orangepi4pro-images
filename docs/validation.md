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
scripts/validate-boot-menu-assets.sh
```

Before any reboot during bootloader work, run the settlement gate:

```bash
sudo scripts/settlement-validate-before-reboot.sh --write-log
```

The gate fails unless both local repos are clean and pushed, the live boot
assets match the current NVMe-primary selector test state, the running kernel
has the expected `bootchooser=extlinux-legacy-nvme` marker, and the SD
bootloader slot byte-matches the expected TOC1 package.

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

If reboot lands on SD with `bootchooser=extlinux-legacy-sd`, see:

```text
docs/extlinux-default-repair.md
```

For the current boot-selection boundary and next gated U-Boot work, see:

```text
docs/boot-selection-plan.md
```

After the first NVMe boot, expected checks:

```bash
uname -r
zgrep -E 'CONFIG_(HID_MULTITOUCH|HIDRAW|UHID|INPUT_UINPUT)=' /proc/config.gz
lsmod | grep -E 'hid_multitouch|uhid|uinput'
libinput list-devices
onboard &
```

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

For the prepared cyberdeck kernel on the mounted NVMe target, use:

```bash
scripts/validate-nvme-cyberdeck-kernel.sh /mnt/orangepi4pro-m2
```

After the first NVMe boot, expected checks:

```bash
uname -r
zgrep -E 'CONFIG_(HID_MULTITOUCH|HIDRAW|UHID|INPUT_UINPUT)=' /proc/config.gz
lsmod | grep -E 'hid_multitouch|uhid|uinput'
libinput list-devices
onboard &
```

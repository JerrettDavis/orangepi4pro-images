# Reboot Resume: 2026-07-02

This system was prepared to reboot with the SD card still inserted.

## Expected Successful Path

The SD `/boot/boot.scr` is now an NVMe-first loader. On reboot it should:

1. boot U-Boot from the same firmware path as before;
2. load the SD `boot.scr`;
3. run `nvme scan`;
4. source `boot.scr` from `nvme 0:2` (`OPI_BOOT`);
5. boot the NVMe Ubuntu root at UUID
   `eb86cfeb-60c7-4513-bc69-f6d28e9d561b`;
6. run kernel `5.15.147-sun60iw2-cyberdeck`.

## Obvious NVMe Markers

The NVMe target was made intentionally different from the SD image:

```text
hostname: opi4pro-nvme-cyberdeck
/etc/cyberdeck-boot-marker
/etc/motd
/etc/issue
/usr/local/bin/cyberdeck-boot-check
```

After reconnecting, run:

```bash
hostname
uname -r
findmnt -no SOURCE,FSTYPE,UUID /
cat /etc/cyberdeck-boot-marker
/usr/local/bin/cyberdeck-boot-check
```

Expected:

```text
hostname: opi4pro-nvme-cyberdeck
kernel: 5.15.147-sun60iw2-cyberdeck
root UUID: eb86cfeb-60c7-4513-bc69-f6d28e9d561b
```

If hostname is still `orangepi4pro`, kernel is still `5.15.147-sun60iw2`, or
root UUID is still `dc683cb4-0847-4d2f-83f1-184d35749d4c`, the system fell back
to SD.

## Native Touch Follow-Up

If NVMe boot succeeds:

```bash
zgrep -E 'CONFIG_(HID_MULTITOUCH|HIDRAW|UHID|INPUT_UINPUT|INPUT_EVDEV|USB_HID)=' /proc/config.gz
lsmod | grep -E 'hid_multitouch|uhid|uinput'
libinput list-devices
sudo evtest
onboard &
```

The old QDtech X11 bridge is disabled on the NVMe clone but kept as fallback.

## Restore SD-Only Boot

If the SD NVMe-first loader causes trouble, restore:

```bash
sudo cp -a /boot/boot.cmd.sd-original-20260702T024525Z /boot/boot.cmd
sudo cp -a /boot/boot.scr.sd-original-20260702T024525Z /boot/boot.scr
sync
```

No SPI flash, MTD device, U-Boot environment sector, or bootloader sector was
modified in this session.

# Install To M.2

Current status: NVMe is partitioned, formatted, mounted, and has a live clone
of the current Orange Pi Ubuntu SD root in `UBUNTU_ROOT`.

See `docs/nvme-layout-actual.md` for the actual labels, UUIDs, and mount
points.
See `docs/nvme-primary-live-clone.md` for the live clone and boot asset notes.

Recommended third-session flow:

1. Run `scripts/mount-nvme-layout.sh` if the partitions are not mounted.
2. Boot-test the live-cloned Ubuntu root from NVMe.
3. Build Kali rootfs with `scripts/bootstrap-kali.sh`, then convert the dry-run
   command into a reviewed rootfs install targeting
   `/mnt/orangepi4pro-m2/kali-root`.
4. Build replacement kernel and boot assets only after the stock/vendor U-Boot
   path is confirmed.
5. Install board support into mounted target rootfs.

The remaining bootstrap scripts still avoid Kali rootfs and bootloader writes by
default. No SPI/MTD/bootloader sectors have been modified.

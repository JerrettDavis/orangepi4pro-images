# Install To M.2

Current status: NVMe is partitioned, formatted, and mounted. Rootfs and boot
installation remain pending.

See `docs/nvme-layout-actual.md` for the actual labels, UUIDs, and mount
points.

Recommended third-session flow:

1. Run `scripts/mount-nvme-layout.sh` if the partitions are not mounted.
2. Build Ubuntu rootfs with `scripts/bootstrap-ubuntu.sh`, then convert the
   dry-run command into a reviewed rootfs install targeting
   `/mnt/orangepi4pro-m2/ubuntu-root`.
3. Build Kali rootfs with `scripts/bootstrap-kali.sh`, then convert the dry-run
   command into a reviewed rootfs install targeting
   `/mnt/orangepi4pro-m2/kali-root`.
4. Build kernel and boot assets only after U-Boot support is confirmed.
5. Install board support into mounted target rootfs.
6. Boot through SD-controlled stock/vendor U-Boot first.

The remaining bootstrap scripts still avoid rootfs and bootloader writes by
default.

# Install To M.2

Current status: dry-run only.

Recommended third-session flow:

1. Run `scripts/validate-target-disk.sh /dev/nvme0n1`.
2. Run `scripts/mk-partitions.sh /dev/nvme0n1` and review the printed `sfdisk`
   plan.
3. Build Ubuntu rootfs with `scripts/bootstrap-ubuntu.sh`.
4. Build Kali rootfs with `scripts/bootstrap-kali.sh`.
5. Build kernel and boot assets only after U-Boot support is confirmed.
6. Install board support into mounted target rootfs.
7. Boot through SD-controlled stock/vendor U-Boot first.

Scripts currently do not write partition tables, filesystems, or rootfs data.


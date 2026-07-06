# SD Recovery NVMe Reimage

This runbook rebuilds an Orange Pi 4 Pro NVMe from the SD recovery system. It
does not require any files from the old NVMe.

## Preconditions

- Booted from the SD card.
- Network works, or the SD card already has current clones in
  `/home/orangepi/orangepi4pro-*`.
- Target disk is visible as `/dev/nvme0n1`.
- No `/dev/nvme0n1p*` partition is mounted.
- The repos are clean and current:

```bash
cd /home/orangepi/orangepi4pro-images
git status --short --branch
git pull --ff-only origin main
```

## Dry Run

```bash
cd /home/orangepi/orangepi4pro-images
scripts/reimage-nvme-from-sd.sh
```

## Execute

This is destructive to the NVMe only. It recreates the GPT, formats all NVMe
partitions, clones the running SD root into `UBUNTU_ROOT`, installs boot assets,
and patches the new `UBUNTU_ROOT` UUID into NVMe and SD boot files.

```bash
cd /home/orangepi/orangepi4pro-images
sudo ORANGEPI4PRO_REIMAGE_NVME=1 scripts/reimage-nvme-from-sd.sh --yes
```

The script refuses write mode unless the current root filesystem is on SD/MMC.
It never writes SPI/MTD.

## Validate

After the script completes:

```bash
scripts/validate-boot-menu-assets.sh
scripts/validate-active-boot-source.sh /mnt/opisd-check
```

Then reboot with the SD card inserted. The SD boot files should select the new
NVMe `UBUNTU_ROOT`.

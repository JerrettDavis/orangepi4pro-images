#!/usr/bin/env bash
set -euo pipefail

base="${1:-/mnt/orangepi4pro-m2}"
root="$base/ubuntu-root"
boot="$base/boot"
efi="$base/efi"

for path in "$root" "$boot" "$efi"; do
  if ! findmnt -M "$path" >/dev/null 2>&1; then
    printf 'ERROR: %s is not mounted\n' "$path" >&2
    exit 1
  fi
done

root_uuid="$(blkid -s UUID -o value /dev/disk/by-label/UBUNTU_ROOT)"
boot_uuid="$(blkid -s UUID -o value /dev/disk/by-label/OPI_BOOT)"
efi_uuid="$(blkid -s UUID -o value /dev/disk/by-label/OPI_EFI)"
tools_uuid="$(blkid -s UUID -o value /dev/disk/by-label/TOOLS)"
home_uuid="$(blkid -s UUID -o value /dev/disk/by-label/HOME)"
cache_uuid="$(blkid -s UUID -o value /dev/disk/by-label/IMAGES_CACHE)"

sudo mkdir -p "$root"/{dev,proc,sys,tmp,run,mnt,media,boot,boot/efi}
sudo chmod 1777 "$root/tmp"
sudo mkdir -p "$root"/opt/cyberdeck-tools "$root"/srv/cyberdeck-home "$root"/var/cache/orangepi4pro-images
sudo chown orangepi:orangepi "$root"/opt/cyberdeck-tools "$root"/srv/cyberdeck-home "$root"/var/cache/orangepi4pro-images

sudo cp -a "$root/etc/fstab" "$root/etc/fstab.backup-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
sudo tee "$root/etc/fstab" >/dev/null <<EOF
# Orange Pi 4 Pro NVMe primary layout.
UUID=$root_uuid / ext4 defaults,noatime,errors=remount-ro 0 1
UUID=$boot_uuid /boot ext4 defaults,noatime 0 2
UUID=$efi_uuid /boot/efi vfat defaults,noatime,umask=0077 0 2
UUID=$tools_uuid /opt/cyberdeck-tools ext4 defaults,noatime,nofail 0 2
UUID=$home_uuid /srv/cyberdeck-home ext4 defaults,noatime,nofail 0 2
UUID=$cache_uuid /var/cache/orangepi4pro-images ext4 defaults,noatime,nofail 0 2
EOF

sudo rsync -a --delete /boot/ "$boot"/
sudo cp -a "$boot/orangepiEnv.txt" "$boot/orangepiEnv.txt.backup-$(date -u +%Y%m%dT%H%M%SZ)"
sudo sed -i "s#^rootdev=.*#rootdev=UUID=$root_uuid#" "$boot/orangepiEnv.txt"
sudo sed -i 's#^rootfstype=.*#rootfstype=ext4#' "$boot/orangepiEnv.txt"
sudo mkimage -C none -A arm -T script -d "$boot/boot.cmd" "$boot/boot.scr"

sudo find "$efi" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
sudo rsync -aL --delete "$boot"/ "$efi"/
sync

printf 'Prepared NVMe boot assets for root UUID %s\n' "$root_uuid"


# Contributing

This repository owns image/rootfs/boot-asset assembly for the Orange Pi 4 Pro
cyberdeck.

## Rules

- Keep scripts dry-run by default unless the script name and docs clearly state
  that it writes to a mounted target.
- Never commit disk images, rootfs archives, downloaded source trees, package
  caches, or mounted target filesystems.
- Record actual UUIDs, labels, boot assets, and kernel versions when a live
  system changes.
- Run `scripts/ci-checks.sh` before pushing.


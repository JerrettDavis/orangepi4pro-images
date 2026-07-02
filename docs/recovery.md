# Recovery Preconditions

Do not run an M.2 install until:

- SD image backup exists and has a SHA256 checksum.
- `/boot`, kernel config, DTB, `dmesg`, `lsusb`, `lspci`, `lsblk`, and touch
  bundle are captured.
- USB keyboard and SD recovery path are confirmed.
- Target disk identity is verified by model and serial.
- Every destructive script has been reviewed with dry-run output.


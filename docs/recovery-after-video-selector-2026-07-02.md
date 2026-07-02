# Recovery After Video Selector Test

Status captured 2026-07-02 after recovery on another machine.

The video-first selector stage in commit `d983f9a` was reverted by
`5c65a1e`. The live machine was also resynced so NVMe `/boot` matches the
recovered SD `/boot` files:

```text
/boot/backups/pre-safe-sd-resync-20260702T231955Z
```

Current boot marker:

```text
bootchooser=extlinux-legacy-nvme
```

That marker means the current SD U-Boot is scanning extlinux before scripts and
does not enter the `boot.scr` bootmenu branch.

Current safe SD boot files:

```text
boot.cmd sha256=141a90676af16385d26e09e6d7ae51fb2fb2fb53825e94d834c02b1d6f915960
boot.scr sha256=8c8fa7728758fbca8d1bd171d82e0a7fc7c34e6f7d29d33d1ee9f7a2e7edaf79
orangepiEnv.txt sha256=ffd99dd9ae9b442bb4bf7d970306d86b3d856899ca30e8f18df31e51f0ea4048
extlinux/extlinux.conf sha256=4902f62d708be00352f10d37efb51846231774629e37b3825a1211b16045d149
```

Current SD bootloader package readback contains:

```text
scan_dev_for_boot=... run scan_dev_for_extlinux; run scan_dev_for_scripts; ...
```

So the script-first package was replaced during recovery.

Do not re-stage `d983f9a`. It changed the normal selector to force video-first
console output and call `sunxi_show_bmp boot.bmp`; that combination caused a
boot hang on this board.

The next selector attempt should not call `sunxi_show_bmp` from `boot.scr`.
Vendor source shows that command is not a simple current-prefix BMP draw: it
rewrites the requested path to `/boot/boot.bmp`, scans hardcoded storage
devices, may use an embedded fallback image, and reinitializes DRM display
state.

After this recovery, repo boot scripts were updated so `selector_bitmap=true`
prints a warning and does not call `sunxi_show_bmp`.

# Source Manifest

See `../orangepi4pro-cyberdeck/docs/sources.md` for source pins.

Image-build inputs should come from official distro repositories:

- Ubuntu arm64 via `mmdebstrap` or `debootstrap`; preferred current LTS:
  `noble` unless a later LTS is explicitly selected and tested.
- Kali arm64 via Kali official repositories; start minimal and add tool
  profiles incrementally.

No large binary images or downloaded source trees should be committed.


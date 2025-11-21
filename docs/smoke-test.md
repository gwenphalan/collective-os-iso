# Smoke Test – 2025-11-21

Commands run by Gwen:
- Build: `./bin/omarchy-iso-make --no-cache --no-boot-offer`
- Boot: `qemu-system-x86_64 -cdrom ./release/*.iso -m 4G`

Results:
- ISO build **succeeded**; output `release/omarchy-2025.11.21-x86_64.iso` (~6.2 G). Upload/sign steps did not run.
- Live ISO **booted** in QEMU with 4 GB RAM.
- Installer **failed during installation** (exact on-screen error not captured; no log file was produced). Gwen can re-run and provide a screenshot for details.

Artifacts:
- Build and boot console output captured in `tmp.log` (workspace root).

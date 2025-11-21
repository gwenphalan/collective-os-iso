# Smoke Test – 2025-11-21

Commands run by Gwen:
- Build: `./bin/omarchy-iso-make --no-cache --no-boot-offer`
- Boot: `qemu-system-x86_64 -cdrom ./release/*.iso -m 8G`

Results:
- ISO build **succeeded**; output `release/omarchy-2025.11.21-x86_64.iso` (~6.2 G). Upload/sign steps did not run.
- Live ISO **booted** in QEMU with 8 GB RAM.
- Installer **failed during installation**: installer step to choose target disk errored with `no options provided, see 'gum choose --help'` and aborted (exit code `1`). Screenshot referenced in session notes. Likely cause: VM launched without an attached virtual disk.

Artifacts:
- Build and boot console output captured in `docs/slim-iso/artifacts/smoke-test.log`.

Suggested rerun (adds a virtio disk):
```bash
qemu-system-x86_64 \
  -cdrom ./release/omarchy-2025.11.21-x86_64.iso \
  -drive file=/tmp/omarchy-test.qcow2,format=qcow2,if=virtio \
  -m 4G
```

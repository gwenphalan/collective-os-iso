# Smoke Test – 2025-11-21

Commands run by Gwen:
- Build: `./bin/omarchy-iso-make --no-cache --no-boot-offer`
- Boot attempts:
  - `qemu-system-x86_64 -cdrom ./release/*.iso -m 8G`
  - With disk attached (virtio): `qemu-system-x86_64 -cdrom ./release/omarchy-2025.11.21-x86_64-master.iso -drive file=/tmp/omarchy-test.qcow2,format=qcow2,if=virtio -m 8G`
  - Headless/TCG variants were also tried to avoid host GL/GPU crashes.

Results:
- ISO build **succeeded**; output `release/omarchy-2025.11.21-x86_64.iso` (~6.2 G). Upload/sign steps did not run.
- Live ISO **booted** in QEMU with 8 GB RAM.
- Installer failures:
  - First run (no disk): `no options provided, see 'gum choose --help'` when selecting target disk; install aborted.
  - Subsequent runs with disk attached progressed into package installation but the VM/terminal crashed repeatedly around the `perl` package install phase. Serial/file logging wasn’t captured because the installer boots to VGA by default.
- Assessment: crashes occur inside the upstream Omarchy installer runtime, not in ISO creation; considered out-of-scope for this cleanup branch.

Artifacts:
- Build and boot console output captured in `docs/slim-iso/artifacts/smoke-test.log`.

Suggested future debug (installer repo scope):
- Boot with a serial console to capture logs: add `console=ttyS0,115200n8` to the kernel cmdline and use `-serial stdio -nographic`, then collect `/tmp/omarchy-install.log` or `journalctl -b`.

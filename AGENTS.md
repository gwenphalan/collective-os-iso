# CollectiveOS ISO Agent Guide

## Project Overview
- Builds the CollectiveOS Arch-based installer ISO—a personal fork of Omarchy. At present it is identical to Omarchy but expected to diverge; keep upstream references in mind when changing defaults.
- Uses upstream `archiso` (submodule pinned to v84) with custom `configs/` overlay and builder scripts to generate installable ISOs.
- Outputs ISOs to `release/`; legacy signing/upload helpers are preserved under `contrib/omarchy-legacy/` but are disabled by default.

## Repo Layout & Tech Stack
- `bin/`: Bash entrypoints for building (`omarchy-iso-make`), booting/testing (`omarchy-iso-boot`), VM snapshotting (`omarchy-vm`), and rclone config helper.
- `contrib/omarchy-legacy/bin/`: Legacy release/sign/upload helpers retained for reference and opt-in use.
- `builder/`: `build-iso.sh` run inside the Arch Linux build container; installs build deps, pulls Omarchy/CollectiveOS sources, builds offline repo, and calls `mkarchiso`.
- `configs/`: ArchISO profile overlay (pacman configs, boot loaders, profiledef, airootfs scripts including `.automated_script.sh` and `configurator`).
- `archiso/`: Git submodule of upstream archiso (do not edit unless updating the submodule).
- `release/`: Build artifacts; `vm-saves/`: persisted QCOW2/OVMF snapshots.
- `docs/`: Cleanup artifacts such as `docs/audit-report.md` and `docs/smoke-test.md` for the `cleanup/iso-slim` branch.
- Predominantly Bash; relies on Arch Linux tooling (pacman, mkarchiso, qemu, gum, rclone, gnupg).

## Dev Environment Setup
- Host: Arch Linux (scripts use `pacman`, `gum`, `qemu-full`, `edk2-ovmf`, Docker).
- Ensure Docker is installed and can run privileged containers.
- Pull submodule: `git submodule update --init --recursive --jobs=8`.
- Optional env vars for builds: `OMARCHY_INSTALLER_REPO` (default `basecamp/omarchy`), `OMARCHY_INSTALLER_REF` (default `master`).
- For optional uploads: configure 1Password CLI and run `./bin/omarchy-iso-rclone-config` to write `~/.config/rclone/rclone.conf` before calling legacy upload helper.

## Core Workflows
- Build ISO:  
  ```bash
  ./bin/omarchy-iso-make [--no-cache] [--no-boot-offer] [--local-source] [--dev]
  ```  
  Runs privileged Docker `archlinux/archlinux:latest`, mounts `archiso/`, `builder/`, `configs/`, `release/`. Caches packages in `~/.cache/omarchy/iso_<date>/` unless `--no-cache`.
- Build internals (inside container): `builder/build-iso.sh` installs archiso/mkarchiso, omarchy-keyring, copies releng profile, overlays configs, clones or mounts Omarchy/CollectiveOS source, downloads & verifies latest Node binary, assembles offline pacman mirror, then runs `mkarchiso`.
- Boot/test ISO in QEMU:  
  ```bash
  ./bin/omarchy-iso-boot [release/omarchy.iso] [reuse]
  ```  
  Installs `qemu-full` & `edk2-ovmf` if missing, creates `/tmp/omarchy-iso-boot.qcow2` (20G) unless `reuse` is passed, forwards SSH on port 2222.
- Manage VM snapshots: `./bin/omarchy-vm save|boot|list [name]` uses `vm-saves/` and `/tmp` QCOW/OVMF files.
- Optional legacy signing/upload (manual/opt-in):  
  Scripts live in `contrib/omarchy-legacy/bin/`. They are *not* invoked automatically; set `UPLOAD_TO_OMARCHY=true` or call directly if needed.
- ISO customization at runtime: `configs/airootfs/root/.automated_script.sh` orchestrates color theming, runs `configurator`, feeds archinstall, mounts offline mirror and Node tarball, and hands off to Omarchy installer.

## Coding Conventions & Architecture Rules
- Bash scripts default to `set -e`/`set -euo pipefail`; keep error handling consistent.
- Treat `archiso/` as external upstream; prefer overlay changes in `configs/` rather than editing the submodule.
- Offline-first: `configs/pacman.conf` and offline mirror paths must stay in sync with `build-iso.sh` mounts (`/var/cache/omarchy/mirror/offline`, `/opt/packages`).
- Profile metadata lives in `configs/profiledef.sh`; file permissions there are enforced in the ISO image.
- `configurator` relies on Omarchy/CollectiveOS helper scripts (`$OMARCHY_INSTALL/helpers/all.sh`) and `gum` UI; keep UX outputs concise and color-safe on TTYs only.
- Anticipate future CollectiveOS divergence: keep naming-compatible for now, but avoid hardcoding brand strings where not required; centralize changes through configs and env vars first.

## Tests / Quality Gates
- No automated tests in-repo. Validate builds by:
  - Running `omarchy-iso-make` to produce an ISO.
  - Booting with `omarchy-iso-boot` and completing the guided install.
  - Verifying signature (`gpg --verify <iso>.sig <iso>`) and checksum (`sha256sum <iso>`).
- Nightly GitHub Action exists but currently references missing `build_iso.sh` (see CI notes).

## CI/CD Notes
- `.github/workflows/nightly-build.yml` schedules a privileged Arch Linux container build and uploads artifacts; flow expects `build_iso.sh` in repo root (currently absent) so the job will fail until aligned with `bin/omarchy-iso-make` or a root-level wrapper.
- `archiso/.gitlab-ci.yml` belongs to the upstream submodule and is not used by this project.

## Risky / Complex Areas
- `builder/build-iso.sh` manipulates keyrings, mirror caches, and downloads Node + packages; mistakes here break offline installs or verification.
- `configs/airootfs/root/.automated_script.sh` performs mounts and passwordless sudo setup inside `/mnt`; changes can leave the target system insecure or unbootable.
- `omarchy-iso-boot` and `omarchy-vm` overwrite `/tmp/omarchy-iso-boot.qcow2` and `/tmp/OVMF_VARS.4m.fd`; be cautious when reusing disks.
- Upload/sign flows rely on secrets (1Password, GPG keys, R2 creds); avoid hardcoding and keep outputs under `release/`.

## Dos and Don’ts for Agents
- Do use root-relative paths (e.g., `collective-os-iso/bin/…`) when coordinating with other agents.
- Do keep submodule state intact; update intentionally with `git submodule update --remote` only when requested.
- Do validate new build steps inside Docker to avoid polluting the host.
- Don’t edit or remove offline mirror/pacman config paths without adjusting `build-iso.sh` and `profiledef.sh`.
- Don’t commit secrets or `~/.config/rclone` contents; the rclone config is generated locally.
- Don’t rely on the existing GitHub Action without fixing its script path.

## Agent History

# ISO0
- ISO0's sole task was to analyze the codebase and generate this AGENTS.md file.

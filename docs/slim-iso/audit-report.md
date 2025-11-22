# Omarchy Infra Reference Audit (cleanup/iso-slim)

For each reference found (search terms: omarchy, upload, release, rclone, omarchy-keyring, omarchy-iso), the table records why it is tied to Omarchy-specific infrastructure and a recommended action. Paths are rooted at `collective-os-iso/`.

| File | Why it is Omarchy infra | Recommended action |
| --- | --- | --- |
| collective-os-iso/README.md | User instructions revolve around the Omarchy installer, omarchy-iso-* scripts, and release/upload flow. | Update after cleanup to describe fork focus; keep dependency notes on `[omarchy]` repo for now. |
| collective-os-iso/AGENTS.md | Project guide documents Omarchy release/upload/signing flow, rclone config, and Omarchy repo defaults. | Refresh doc once legacy scripts are moved; keep historical note that `[omarchy]` repo and `omarchy-keyring` remain required. |
| collective-os-iso/bin/omarchy-iso-release | One-shot release pipeline: remakes ISO, signs, uploads to Omarchy bucket. | Relocate to `contrib/omarchy-legacy` and keep out of default flow. |
| collective-os-iso/bin/omarchy-iso-upload | Uses rclone with Omarchy Cloudflare S3 remote (`Omarchy:omarchy/`) to upload ISO and sig. | Relocate to `contrib/omarchy-legacy`; do not call automatically. |
| collective-os-iso/bin/omarchy-iso-sign | GPG signing helper for release flow. | Relocate to `contrib/omarchy-legacy`; keep optional/manual. |
| collective-os-iso/bin/omarchy-iso-rclone-config | Pulls Omarchy bucket credentials from 1Password to write rclone config. | Move to `contrib/omarchy-legacy` or clearly mark as optional legacy tooling. |
| collective-os-iso/bin/omarchy-iso-make | Builds ISO; default repo/ref point to Omarchy; output renames to `*-<OMARCHY_INSTALLER_REF>.iso`; optionally prompts to boot. No upload guard present. | Keep build defaults but ensure any future signing/upload stays behind explicit opt-in (e.g., `UPLOAD_TO_OMARCHY`). |
| collective-os-iso/bin/omarchy-iso-boot | Names temp disk `/tmp/omarchy-iso-boot.qcow2`; branding-specific but not critical infra. | Leave as-is for now; optional rebrand later. |
| collective-os-iso/bin/omarchy-vm | Manages snapshots for `omarchy-iso-boot` disks; branding-specific. | Leave as-is; consider rename in future rebrand. |
| collective-os-iso/bin/omarchy-iso-upload (referenced in README/AGENTS) | Listed in docs as upload path to Omarchy infra. | Covered by relocation above; docs to be updated post-cleanup. |
| collective-os-iso/configs/profiledef.sh | Sets `iso_name="omarchy"`, Omarchy publisher string, installs `/usr/local/bin/omarchy-upload-log`, and permissions for `/var/cache/omarchy`. | Leave functional values for now; flag upload-log path for later removal if no upstream dependency. |
| collective-os-iso/configs/pacman.conf | Offline repo path `/var/cache/omarchy/mirror/offline`. | Keep; required for offline mirror layout. |
| collective-os-iso/configs/pacman-online.conf | Uses Omarchy CDN mirrors and `[omarchy]` repo (SigLevel Optional TrustAll). | Keep for current dependency; add warning comment about external Omarchy repo reliance. |
| collective-os-iso/builder/build-iso.sh | Installs `omarchy-keyring`, clones Omarchy installer, copies Omarchy upload-log and Plymouth theme, builds offline mirror using `[omarchy]`. | Keep keyring and repo usage; gate copying of Omarchy assets/upload-log behind a flag; document dependency on `[omarchy]` repo. |
| collective-os-iso/configs/airootfs/root/configurator | Defaults hostname to `omarchy`, loads Omarchy mirror URL, includes `omarchy-keyring` in package list. | Keep behavior (installer depends on Omarchy packages); future rebrand can revisit defaults. |
| collective-os-iso/configs/airootfs/etc/plymouth/plymouthd.conf | Hard-codes Plymouth theme `omarchy`. | Leave for now; will change when branding/themes are revisited. |
| collective-os-iso/configs/profiledef.sh (layout) | Permissions include `/var/cache/omarchy/...` mirror and `omarchy-upload-log`. | Keep mirror paths; mark upload-log for later removal. |
| collective-os-iso/.github/workflows/nightly-build.yml | CI job expects root `build_iso.sh` and uploads artifacts named `omarchy-iso-*`; assumes release automation. | Update workflow later to call `bin/omarchy-iso-make` or disable nightly release until infra decisions are made. |
| collective-os-iso/bin/omarchy-iso-boot README references | Documentation encourages using Omarchy-branded boot script. | Accept for now; adjust docs after cleanup. |
| collective-os-iso/archiso/ (submodule) | Contains generic "release" wording unrelated to Omarchy; not part of infra. | No action. |

## Notes on preserved dependencies
- The ISO currently **requires** packages from the external `[omarchy]` pacman repository and the `omarchy-keyring` for verification. These must remain until the installer and package sources are decoupled in a future pass.

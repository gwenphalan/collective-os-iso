# CollectiveOS ISO (fork of omacom-io/omarchy-iso)

This project is a fork of `omacom-io/omarchy-iso`, used as the base for building a CollectiveOS ISO. It still uses the Omarchy installer from `basecamp/omarchy` and the upstream `[omarchy]` pacman repository (plus `omarchy-keyring`) for now.

## Downloading the ISO

There is currently no official CollectiveOS ISO download. Build locally using the instructions below.

## Creating the ISO

Run `./bin/omarchy-iso-make` and the output goes into `./release`. You can build from your local $OMARCHY_PATH for testing by using `--local-source` or from a checkout of the dev branch (instead of master) by using `--dev`.

### Environment Variables

You can customize the installer source by passing in variables (defaults are intentionally kept pointing at the upstream Omarchy installer until CollectiveOS replaces it):

- `OMARCHY_INSTALLER_REPO` - GitHub repository for the installer (default: `basecamp/omarchy`)
- `OMARCHY_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)

Example usage:
```bash
OMARCHY_INSTALLER_REPO="myuser/omarchy-fork" OMARCHY_INSTALLER_REF="some-feature" ./bin/omarchy-iso-make
```

## Testing the ISO

Run `./bin/omarchy-iso-boot [release/omarchy.iso]`.

## Legacy release helpers

Legacy Omarchy signing/upload tooling is preserved in `contrib/omarchy-legacy/bin/` for reference. It is **disabled by default**; to use it, call the scripts directly or set `UPLOAD_TO_OMARCHY=true` when running `./bin/omarchy-iso-make`.

## Cleanup documentation

- Audit: `docs/slim-iso/audit-report.md`
- Smoke test results: `docs/slim-iso/smoke-test.md`

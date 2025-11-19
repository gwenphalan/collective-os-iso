# CollectiveOS ISO

The CollectiveOS ISO streamlines the installation of CollectiveOS, our customized fork of Omarchy. It includes the CollectiveOS Configurator as a front-end to archinstall and automatically launches the [CollectiveOS installer](https://github.com/gwenphalan/collective-os) after the base Arch system is prepared.

## Downloading the latest ISO

See the ISO link on [omarchy.org](https://omarchy.org).

## Creating the ISO

Run `./bin/collectiveos-iso-make` and the output goes into `./release`. You can build from your local $COLLECTIVEOS_PATH for testing by using `--local-source` or from a checkout of the dev branch (instead of master) by using `--dev`.

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `COLLECTIVEOS_INSTALLER_REPO` - GitHub repository for the installer (default: `gwenphalan/collective-os`)
- `COLLECTIVEOS_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)

Example usage:
```bash
COLLECTIVEOS_INSTALLER_REPO="myuser/collectiveos-fork" COLLECTIVEOS_INSTALLER_REF="some-feature" ./bin/collectiveos-iso-make
```

### Package repositories

CollectiveOS packages are still hosted on the Omarchy mirrors (`https://stable-mirror.omarchy.org` and `https://pkgs.omarchy.org`). For compatibility, the pacman configuration shipped inside the ISO continues to expose these as the `[omarchy]` repository and ships the `omarchy-keyring` for signature verification.

## Testing the ISO

Run `./bin/collectiveos-iso-boot [release/collectiveos.iso]`.

## Signing the ISO

Run `./bin/collectiveos-iso-sign [gpg-user] [release/collectiveos.iso]`.

## Full release of the ISO

Run `./bin/collectiveos-iso-release` to create, test, and sign the ISO in one flow.

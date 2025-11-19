Limine override packages for CollectiveOS ISO
============================================

This directory vendors AUR PKGBUILDs that must always be available inside the
CollectiveOS ISO even if the installer repo does not prebuild them.

Packages:
- limine-snapper-sync
- limine-mkinitcpio-hook

`builder/build-iso.sh` automatically builds any overrides that are missing from
`collectiveos/repos/local-aur/x86_64` and injects the resulting packages into the
offline pacman mirror (`/var/cache/collectiveos/mirror/offline`).

#!/bin/bash

set -e

# Default AUR packages in case the installer repo does not provide its own list
DEFAULT_AUR_PACKAGES=(modrinth-app proton-authenticator-bin proton-pass-bin qt5-remoteobjects)

AUR_BUILD_USER=${AUR_BUILD_USER:-aurbuilder}
AUR_SUDOERS_FILE="/etc/sudoers.d/collectiveos-aur"

ensure_aur_build_user() {
  if ! id -u "$AUR_BUILD_USER" >/dev/null 2>&1; then
    useradd -m "$AUR_BUILD_USER"
  fi

  local sudoers_entry="$AUR_BUILD_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman"
  if [[ ! -f "$AUR_SUDOERS_FILE" ]] || ! grep -Fxq "$sudoers_entry" "$AUR_SUDOERS_FILE"; then
    local tmp_sudoers
    tmp_sudoers=$(mktemp)
    printf '%s\n' "$sudoers_entry" >"$tmp_sudoers"
    if ! visudo -cf "$tmp_sudoers" >/dev/null; then
      echo "ERROR: Failed to validate sudoers entry for $AUR_BUILD_USER" >&2
      rm -f "$tmp_sudoers"
      exit 1
    fi
    install -m 440 "$tmp_sudoers" "$AUR_SUDOERS_FILE"
    rm -f "$tmp_sudoers"
  fi
}

build_override_packages_for_missing() {
  local override_root="/builder/aur-overrides"
  local next_missing=()

  if [[ ! -d "$override_root" || ${#missing_aur_pkgs[@]} -eq 0 ]]; then
    return
  fi

  ensure_aur_build_user
  mkdir -p /tmp/collectiveos-aur-overrides

  for pkg in "${missing_aur_pkgs[@]}"; do
    local src="$override_root/$pkg"
    if [[ ! -d "$src" ]]; then
      next_missing+=("$pkg")
      continue
    fi

    local build_dir="/tmp/collectiveos-aur-overrides/$pkg"
    rm -rf "$build_dir"
    mkdir -p "$(dirname "$build_dir")"
    cp -r "$src" "$build_dir"
    chown -R "$AUR_BUILD_USER:$AUR_BUILD_USER" "$build_dir"

    if ! runuser -u "$AUR_BUILD_USER" -- bash -lc "cd '$build_dir' && makepkg -s --noconfirm"; then
      echo "WARNING: Failed to build override package $pkg" >&2
      next_missing+=("$pkg")
      continue
    fi

    shopt -s nullglob
    local built_pkgs=("$build_dir"/*.pkg.tar.*)
    shopt -u nullglob
    if [[ ${#built_pkgs[@]} -eq 0 ]]; then
      echo "WARNING: Override build for $pkg produced no artifacts" >&2
      next_missing+=("$pkg")
      continue
    fi

    cp -u "${built_pkgs[@]}" "$offline_mirror_dir/"
    local installer_repo_local_aur="$INSTALLER_DEST/repos/local-aur/x86_64"
    mkdir -p "$installer_repo_local_aur"
    cp "${built_pkgs[@]}" "$installer_repo_local_aur/"
  done

  missing_aur_pkgs=("${next_missing[@]}")
}

# Note that these are packages installed to the Arch container used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Syu
pacman --noconfirm -Sy archiso git sudo base-devel jq grub jdk21-openjdk maven

# Provide swap to prevent OOM when building large Rust AUR packages
SWAPFILE_PATH="${ISO_SWAPFILE:-/swapfile}"
SWAPFILE_SIZE_GB="${ISO_SWAP_SIZE_GB:-8}"
SWAP_LOOP_DEVICE=""
cleanup_swap() {
  if [[ -n "$SWAP_LOOP_DEVICE" ]]; then
    swapoff "$SWAP_LOOP_DEVICE" || true
    losetup -d "$SWAP_LOOP_DEVICE" || true
  fi
}
ensure_loop_devices() {
  if [[ ! -e /dev/loop-control ]]; then
    mknod /dev/loop-control c 10 237
    chmod 660 /dev/loop-control
  fi
  for i in $(seq 0 7); do
    dev="/dev/loop$i"
    if [[ ! -e "$dev" ]]; then
      mknod "$dev" b 7 $i
      chmod 660 "$dev"
    fi
  done
}
if [[ -z "${SKIP_ISO_SWAP:-}" ]]; then
  if [[ ! -f "$SWAPFILE_PATH" ]]; then
    required_kb=$((SWAPFILE_SIZE_GB * 1024 * 1024))
    available_kb=$(df --output=avail / | tail -n1)
    if [[ $available_kb -lt $required_kb ]]; then
      echo "ERROR: Insufficient disk space for ${SWAPFILE_SIZE_GB}GB swap file" >&2
      exit 1
    fi
    dd if=/dev/zero of="$SWAPFILE_PATH" bs=1M count=$((SWAPFILE_SIZE_GB * 1024)) status=none
    chmod 600 "$SWAPFILE_PATH"
  fi
  ensure_loop_devices
  SWAP_LOOP_DEVICE=$(losetup --show -f "$SWAPFILE_PATH")
  # mkswap performs sanity checks; the loop device was freshly created so forcing is unnecessary.
  mkswap "$SWAP_LOOP_DEVICE"
  swapon "$SWAP_LOOP_DEVICE"
  trap cleanup_swap EXIT
fi

# Import Cider Collective key for cidercollective repo before using pacman-online.conf
CIDER_KEY_ID="A0CD6B993438E22634450CDD2A236C3F42A61682"
if ! pacman-key --list-keys "$CIDER_KEY_ID" >/dev/null 2>&1; then
  for i in {1..3}; do
    if curl -fsSL --max-time 30 https://repo.cider.sh/ARCH-GPG-KEY -o /tmp/cider-key.gpg; then
      break
    fi
    if [[ $i -eq 3 ]]; then
      echo "ERROR: Failed to download CIDER key after 3 attempts" >&2
      exit 1
    fi
    sleep 2
  done
  pacman-key --add /tmp/cider-key.gpg
  pacman-key --lsign-key "$CIDER_KEY_ID"
fi

# Install omarchy-keyring for package verification during build
# The [omarchy] repo remains defined in /configs/pacman-online.conf with SigLevel = Optional TrustAll
pacman --config /configs/pacman-online.conf --noconfirm -Sy omarchy-keyring
pacman-key --populate omarchy

# Setup build locations
build_cache_dir="/var/cache"
offline_mirror_dir="$build_cache_dir/airootfs/var/cache/collectiveos/mirror/offline"
mkdir -p $build_cache_dir/
mkdir -p $offline_mirror_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r /archiso/configs/releng/* $build_cache_dir/
rm "$build_cache_dir/airootfs/etc/motd"

# Avoid using reflector for mirror identification as we are relying on the global CDN
rm "$build_cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
rm -rf "$build_cache_dir/airootfs/etc/systemd/system/reflector.service.d"
rm -rf "$build_cache_dir/airootfs/etc/xdg/reflector"

# Bring in our configs
cp -r /configs/* $build_cache_dir/

# Determine installer source
INSTALLER_REPO="${COLLECTIVEOS_INSTALLER_REPO:-gwenphalan/collective-os}"
INSTALLER_REF="${COLLECTIVEOS_INSTALLER_REF:-master}"

# Setup CollectiveOS itself
INSTALLER_DEST="$build_cache_dir/airootfs/root/collectiveos"
if [[ -d /collectiveos ]]; then
  cp -rp /collectiveos "$INSTALLER_DEST"
else
  git clone -b "$INSTALLER_REF" "https://github.com/$INSTALLER_REPO.git" "$INSTALLER_DEST"
fi

# Load the list of packages that must be prebuilt by the installer repo
AUR_PACKAGES=()
AUR_PACKAGE_FILE="$INSTALLER_DEST/install/collectiveos-aur.packages"
if [[ -f "$AUR_PACKAGE_FILE" ]]; then
  mapfile -t AUR_PACKAGES < <(grep -Ev '^\s*(#|$)' "$AUR_PACKAGE_FILE")
  if [[ ${#AUR_PACKAGES[@]} -eq 0 ]]; then
    echo "WARNING: $AUR_PACKAGE_FILE is empty; no AUR packages will be injected" >&2
  fi
else
  echo "WARNING: $AUR_PACKAGE_FILE not found; falling back to default AUR package list" >&2
  AUR_PACKAGES=("${DEFAULT_AUR_PACKAGES[@]}")
fi

# Ensure Limine helper packages are always prebuilt for offline installs
REQUIRED_LIMINE_AUR_PACKAGES=(limine-snapper-sync limine-mkinitcpio-hook)
AUR_PACKAGES+=("${REQUIRED_LIMINE_AUR_PACKAGES[@]}")

declare -A AUR_PACKAGE_SET=()
for pkg in "${AUR_PACKAGES[@]}"; do
  AUR_PACKAGE_SET[$pkg]=1
done

# Build AUR packages inside the installer repo so they're available to the ISO build
if [[ -z "${SKIP_LOCAL_AUR_BUILD:-}" ]]; then
  if [[ -x "$INSTALLER_DEST/scripts/build-local-aur.sh" ]]; then
    # Keep Rust AUR builds from exhausting RAM: default to 2 jobs unless overridden.
    AUR_CARGO_JOBS="${CARGO_BUILD_JOBS:-2}"
    AUR_RUSTFLAGS="${RUSTFLAGS:--Ccodegen-units=2}"
    echo "==> Building CollectiveOS AUR packages (CARGO_BUILD_JOBS=$AUR_CARGO_JOBS, RUSTFLAGS=$AUR_RUSTFLAGS)"

    ensure_aur_build_user

    chown -R "$AUR_BUILD_USER:$AUR_BUILD_USER" "$INSTALLER_DEST"
    pushd "$INSTALLER_DEST" >/dev/null
    if ! runuser -u "$AUR_BUILD_USER" -- env "CARGO_BUILD_JOBS=$AUR_CARGO_JOBS" "RUSTFLAGS=$AUR_RUSTFLAGS" ./scripts/build-local-aur.sh; then
      popd >/dev/null
      chown -R root:root "$INSTALLER_DEST"
      echo "ERROR: build-local-aur.sh failed" >&2
      exit 1
    fi
    popd >/dev/null
    chown -R root:root "$INSTALLER_DEST"
  else
    echo "WARNING: build-local-aur.sh not found; skipping local AUR build" >&2
  fi
else
  echo "==> Skipping local AUR build (SKIP_LOCAL_AUR_BUILD set)"
fi

# Make log uploader available in the ISO too
mkdir -p "$build_cache_dir/airootfs/usr/local/bin/"
cp "$INSTALLER_DEST/bin/collectiveos-upload-log" "$build_cache_dir/airootfs/usr/local/bin/collectiveos-upload-log"

# Copy the CollectiveOS Plymouth theme to the ISO
mkdir -p "$build_cache_dir/airootfs/usr/share/plymouth/themes/collectiveos"
cp -r "$INSTALLER_DEST/default/plymouth/"* "$build_cache_dir/airootfs/usr/share/plymouth/themes/collectiveos/"

# Provide Archinstall with an offline pacman configuration during ISO installs
if [[ -f "$INSTALLER_DEST/default/pacman/pacman-offline.conf" ]]; then
  mkdir -p "$build_cache_dir/airootfs/etc"
  cp "$INSTALLER_DEST/default/pacman/pacman-offline.conf" "$build_cache_dir/airootfs/etc/pacman-offline.conf"
fi

# Download and verify Node.js binary for offline installation
NODE_DIST_URL="https://nodejs.org/dist/latest"

# Get checksums and parse filename and SHA
NODE_SHASUMS=$(curl -fsSL "$NODE_DIST_URL/SHASUMS256.txt")
NODE_FILENAME=$(echo "$NODE_SHASUMS" | grep "linux-x64.tar.gz" | awk '{print $2}')
NODE_SHA=$(echo "$NODE_SHASUMS" | grep "linux-x64.tar.gz" | awk '{print $1}')

# Download the tarball
curl -fsSL "$NODE_DIST_URL/$NODE_FILENAME" -o "/tmp/$NODE_FILENAME"

# Verify SHA256 checksum
echo "$NODE_SHA /tmp/$NODE_FILENAME" | sha256sum -c - || {
    echo "ERROR: Node.js checksum verification failed!"
    exit 1
}

# Copy to ISO
mkdir -p "$build_cache_dir/airootfs/opt/packages/"
cp "/tmp/$NODE_FILENAME" "$build_cache_dir/airootfs/opt/packages/"

# Add our additional packages to packages.x86_64
arch_packages=(linux-t2 git gum jq openssl plymouth tzupdate omarchy-keyring)
printf '%s\n' "${arch_packages[@]}" >>"$build_cache_dir/packages.x86_64"

# Build list of all the packages needed for the offline mirror
all_packages=($(cat "$build_cache_dir/packages.x86_64"))
all_packages+=($(grep -v '^#' "$INSTALLER_DEST/install/collectiveos-base.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' "$INSTALLER_DEST/install/collectiveos-other.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' /builder/archinstall.packages | grep -v '^$'))

# Remove packages that must be provided by the installer repo to avoid pacman fetch failures
if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
  filtered_packages=()
  for pkg in "${all_packages[@]}"; do
    if [[ -z "${AUR_PACKAGE_SET[$pkg]:-}" ]]; then
      filtered_packages+=("$pkg")
    fi
  done
  all_packages=("${filtered_packages[@]}")
fi

# Download all the packages to the offline mirror inside the ISO
mkdir -p /tmp/offlinedb
if [[ ${#all_packages[@]} -gt 0 ]]; then
  pacman --config /configs/pacman-online.conf --noconfirm -Syw "${all_packages[@]}" --cachedir $offline_mirror_dir/ --dbpath /tmp/offlinedb
fi

# Copy locally supplied packages built by the installer repository
missing_aur_pkgs=()
if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
  LOCAL_AUR_REPO_DIR="$INSTALLER_DEST/repos/local-aur/x86_64"
  if [[ -d "$LOCAL_AUR_REPO_DIR" ]]; then
    for pkg in "${AUR_PACKAGES[@]}"; do
      pkg_glob="$LOCAL_AUR_REPO_DIR/${pkg}-*.pkg.tar.*"
      if compgen -G "$pkg_glob" >/dev/null; then
        cp -u $pkg_glob "$offline_mirror_dir/"
      else
        missing_aur_pkgs+=("$pkg")
      fi
    done
  else
    missing_aur_pkgs=("${AUR_PACKAGES[@]}")
  fi
fi

if [[ ${#missing_aur_pkgs[@]} -gt 0 ]]; then
  build_override_packages_for_missing
fi

if [[ ${#missing_aur_pkgs[@]} -gt 0 ]]; then
  echo "ERROR: Missing locally built CollectiveOS packages (build stage incomplete): ${missing_aur_pkgs[*]}" >&2
  exit 1
fi

shopt -s nullglob
offline_pkgs=("$offline_mirror_dir"/*.pkg.tar.zst)
shopt -u nullglob
if [[ ${#offline_pkgs[@]} -eq 0 ]]; then
  echo "ERROR: Offline mirror contains no packages" >&2
  exit 1
fi
repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "${offline_pkgs[@]}"

# Create a symlink to the offline mirror instead of duplicating it.
# mkarchiso needs packages at /var/cache/collectiveos/mirror/offline in the container,
# but they're actually in $build_cache_dir/airootfs/var/cache/collectiveos/mirror/offline
mkdir -p /var/cache/collectiveos/mirror
ln -sfn "$offline_mirror_dir" "/var/cache/collectiveos/mirror/offline"

# Copy the pacman.conf to the ISO's /etc directory so the live environment uses our
# same config when booted
cp $build_cache_dir/pacman.conf "$build_cache_dir/airootfs/etc/pacman.conf"

# Finally, we assemble the entire ISO
mkarchiso -v -w "$build_cache_dir/work/" -o "/out/" "$build_cache_dir/"

# Fix ownership of output files to match host user
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    chown -R "$HOST_UID:$HOST_GID" /out/
fi

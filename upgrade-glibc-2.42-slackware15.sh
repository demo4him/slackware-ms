#!/bin/bash
# KISS helper for the three packages supplied in glibc-2.42.zip.
# Target: Slackware64 15.0. Source: slackware.uk TESTING only.
# TESTING packages are not part of the stable Slackware 15.0 release.

set -u

BASE_URL="https://slackware.uk/slackware/slackware64-15.0/testing/packages/binutils-gcc-glibc"
WORKDIR="${GLIBC_WORKDIR:-${HOME}/glibc-2.42-slackware15}"
PACKAGES=(
  "aaa_glibc-solibs-2.42-x86_64-1_slack15.0.txz"
  "glibc-2.42-x86_64-1_slack15.0.txz"
  "binutils-2.45-x86_64-1_slack15.0.txz"
)

have_dialog=0
command -v dialog >/dev/null 2>&1 && have_dialog=1

msg() {
  if [ "$have_dialog" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
    dialog --title "glibc 2.42 - Slackware 15.0" --msgbox "$1" 13 76
  else
    printf '\n%s\n\n' "$1"
  fi
}

fail() {
  if [ "$have_dialog" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
    dialog --title "Error" --msgbox "$1" 10 76 || true
  else
    printf '\nERROR: %s\n' "$1" >&2
  fi
  exit 1
}

safety_notes() {
  local notes
  notes="This script targets Slackware64 15.0 and downloads only three named TXZ packages from slackware.uk TESTING:\n\n- aaa_glibc-solibs 2.42\n- glibc 2.42\n- binutils 2.45\n\nThe official README says these toolchain packages are only lightly tested and are expected to work for runtime purposes. They are not a stable Slackware 15.0 update. The README notes that rollback is possible by upgrading back to the previous packages, but software compiled after the update may stop working.\n\nThis script downloads .asc signature files but DOES NOT verify them cryptographically. Do not treat the downloads as authenticated. Make sure you have recovery media and a tested backup before installation.\n\nOnly install these packages if you specifically need this testing toolchain for compatibility."
  if [ "$have_dialog" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
    dialog --title "Important notes - TESTING packages" --msgbox "$notes" 22 78
  else
    printf '%b\n' "$notes"
    printf '\nPress Enter to continue... '
    read -r _ || true
  fi
}

choose_action() {
  if [ "$have_dialog" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
    dialog --clear --title "glibc 2.42 - Slackware 15.0" \
      --menu "Choose an action. These packages are from TESTING, not stable." 17 76 6 \
      download "Download packages only" \
      install "Download and install packages" \
      notes "Read safety notes" \
      exit "Exit without changes" 2>&1 >/dev/tty
  else
    printf '%s\n' '1) Download packages only' '2) Download and install packages' '3) Read safety notes' '4) Exit' >&2
    printf 'Choose [1-4]: ' >&2
    read -r choice || choice=4
    case "$choice" in
      1) printf 'download\n' ;;
      2) printf 'install\n' ;;
      3) printf 'notes\n' ;;
      *) printf 'exit\n' ;;
    esac
  fi
}

[ "$(uname -m)" = "x86_64" ] || fail "This script is only for x86_64 systems."
[ -r /etc/slackware-version ] || fail "Cannot identify Slackware version."
grep -q 'Slackware 15.0' /etc/slackware-version || fail "This script targets Slackware 15.0 only."
command -v wget >/dev/null 2>&1 || fail "wget is required. Install it using your normal Slackware tools first."
command -v tar >/dev/null 2>&1 || fail "tar is required."

while :; do
  ACTION="$(choose_action)" || exit 0
  case "$ACTION" in
    notes) safety_notes ;;
    download|install) break ;;
    *) clear 2>/dev/null || true; exit 0 ;;
  esac
done

if [ "$ACTION" = "install" ]; then
  [ "$(id -u)" -eq 0 ] || fail "Installation requires root. Run this script as root with su, after reviewing the safety notes."
  command -v upgradepkg >/dev/null 2>&1 || fail "Slackware upgradepkg command was not found."
fi

mkdir -p "$WORKDIR" || fail "Cannot create work directory: $WORKDIR"
chmod 700 "$WORKDIR" || fail "Cannot secure work directory: $WORKDIR"
cd "$WORKDIR" || fail "Cannot enter work directory: $WORKDIR"

msg "Target: Slackware64 15.0\nSource: slackware.uk TESTING\n\nOnly these three packages will be downloaded:\n\n${PACKAGES[0]}\n${PACKAGES[1]}\n${PACKAGES[2]}\n\nNo other package source is used."

# Download the upstream README so the user has the source's own notes beside the packages.
if ! wget -q --https-only --timeout=30 --tries=3 "$BASE_URL/README" -O README.slackware-testing.part; then
  rm -f README.slackware-testing.part
  fail "Could not download the official testing README. No packages were installed."
fi
[ -s README.slackware-testing.part ] || fail "The official testing README is empty."
mv -f README.slackware-testing.part README.slackware-testing

for pkg in "${PACKAGES[@]}"; do
  if ! wget -q --https-only --timeout=30 --tries=3 "$BASE_URL/$pkg" -O "$pkg.part"; then
    rm -f "$pkg.part"
    fail "Download failed: $pkg\n\nCheck the Slackware UK testing directory and your connection."
  fi
  [ -s "$pkg.part" ] || fail "Downloaded file is empty: $pkg"
  mv -f "$pkg.part" "$pkg"

  # TXZ is xz-compressed; tar -tf auto-detects the compression format.
  if ! tar -tf "$pkg" >/dev/null 2>&1; then
    fail "Downloaded file is not a readable TXZ archive: $pkg"
  fi

  # Save detached signatures for manual verification; this script does not verify them.
  if ! wget -q --https-only --timeout=30 --tries=3 "$BASE_URL/$pkg.asc" -O "$pkg.asc.part"; then
    rm -f "$pkg.asc.part"
    msg "Warning: could not download the signature for $pkg. Authenticity remains unverified."
  elif [ -s "$pkg.asc.part" ]; then
    mv -f "$pkg.asc.part" "$pkg.asc"
  else
    rm -f "$pkg.asc.part"
    msg "Warning: the signature file for $pkg is empty. Authenticity remains unverified."
  fi
done

msg "Download complete.\n\nThe three TXZ archives passed a tar listing check.\n\nFiles are in:\n$WORKDIR\n\nThe upstream README is saved as README.slackware-testing.\n\nIMPORTANT: detached signatures have NOT been cryptographically verified."

if [ "$ACTION" = "download" ]; then
  msg "Download-only mode selected. Nothing has been installed.\n\nFiles: $WORKDIR"
  exit 0
fi

WARNING="You are about to upgrade critical system libraries using TESTING packages. This can make the system unusable if incompatible.\n\nExactly these packages will be passed to upgradepkg, in this order:\n\n${PACKAGES[0]}\n${PACKAGES[1]}\n${PACKAGES[2]}\n\nThe signatures have NOT been verified by this script.\n\nEnsure that you have recovery media and a tested backup. Continue only if you accept the risk."
if [ "$have_dialog" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
  dialog --title "WARNING - system-critical packages" --yesno "$WARNING" 22 78 || {
    msg "Cancelled. No packages were installed. Files remain in $WORKDIR"
    exit 0
  }
else
  printf '\nWARNING:\n%b\n\nType YES to install these packages: ' "$WARNING"
  read -r answer || answer=""
  [ "$answer" = "YES" ] || { msg "Cancelled. No packages were installed."; exit 0; }
fi

# Slackware's upgradepkg replaces installed packages; --install-new also permits missing ones.
# Runtime shared libraries first, then the glibc package, then binutils.
for pkg in "${PACKAGES[@]}"; do
  msg "Running upgradepkg for:\n$pkg\n\nReview the command output before continuing."
  if ! upgradepkg --install-new "./$pkg"; then
    fail "upgradepkg reported a failure for $pkg. Stop here and inspect the system before attempting anything else."
  fi
done

if [ -x /sbin/ldconfig ]; then
  /sbin/ldconfig || fail "Package commands completed, but /sbin/ldconfig failed. Inspect the system before rebooting."
fi
msg "upgradepkg completed for all three selected packages.\n\nReview all terminal output and test essential commands before rebooting.\n\nDownloaded packages and the official README remain in:\n$WORKDIR"

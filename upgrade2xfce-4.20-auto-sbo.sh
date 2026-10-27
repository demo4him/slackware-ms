#!/bin/bash
# XFCE 4.16 -> 4.20 selective upgrade
# Slackware 15.0 x86_64
# Automatically install SBo prerequisites required by the selected Salix packages.

set -uo pipefail

CONFIG="/etc/slapt-get/slapt-getrc"
LOG="/var/log/xfce420-upgrade.log"
REPO="https://slackware.uk/salix/x86_64/xfce4.20-15.0/:PREFERRED"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root."
    exit 1
fi

for cmd in slapt-get sboinstall; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' is not installed."
        exit 1
    fi
done

if [ ! -r "$CONFIG" ]; then
    echo "Error: cannot read $CONFIG"
    exit 1
fi

if ! grep -Fq "$REPO" "$CONFIG"; then
    echo "Error: XFCE 4.20 repository is missing."
    exit 1
fi

mkdir -p "$(dirname "$LOG")" || exit 1
: > "$LOG" || {
    echo "Error: cannot write log $LOG"
    exit 1
}

log() {
    printf '%s\n' "$*" | tee -a "$LOG"
}

# Return success when a package with this exact package-name prefix is installed.
# Slackware package log names include version/build after the package name.
is_installed() {
    local wanted="$1"
    local file base name
    for file in /var/log/packages/*; do
        [ -f "$file" ] || continue
        base="${file##*/}"
        name="$(printf '%s\n' "$base" | sed -E 's/-[0-9].*$//')"
        [ "$name" = "$wanted" ] && return 0
    done
    return 1
}

# colord's SBo README requests a dedicated group and service account.
# Prefer the documented IDs when free; otherwise let Slackware allocate free IDs.
ensure_colord_account() {
    if ! getent group colord >/dev/null 2>&1; then
        if ! getent group 303 >/dev/null 2>&1; then
            groupadd -g 303 colord || return 1
        else
            groupadd colord || return 1
        fi
    fi

    if ! getent passwd colord >/dev/null 2>&1; then
        local gid
        gid="$(getent group colord | cut -d: -f3)"
        if ! getent passwd 303 >/dev/null 2>&1; then
            useradd -u 303 -g "$gid" -d /var/lib/colord -s /bin/false -c "Color management daemon" colord || return 1
        else
            useradd -g "$gid" -d /var/lib/colord -s /bin/false -c "Color management daemon" colord || return 1
        fi
    fi
    mkdir -p /var/lib/colord || return 1
    chown colord:colord /var/lib/colord || return 1
}

# These SBo packages are needed because gtk+3 from the configured Salix repo
# declares colord as a dependency, and colord's SBo recipe requires libgusb.
log "=== SBo prerequisites ==="
if ! is_installed libgusb; then
    log "Installing missing SBo package: libgusb"
    if ! sboinstall -r libgusb 2>&1 | tee -a "$LOG"; then
        log "ERROR: libgusb installation failed; stopping."
        exit 1
    fi
else
    log "libgusb is already installed; skipping."
fi

if ! is_installed colord; then
    log "Preparing the colord service account..."
    if ! ensure_colord_account; then
        log "ERROR: could not prepare the colord group/account; stopping."
        exit 1
    fi
    log "Installing missing SBo package: colord"
    if ! sboinstall -r colord 2>&1 | tee -a "$LOG"; then
        log "ERROR: colord installation failed; stopping."
        exit 1
    fi
else
    log "colord is already installed; skipping."
fi

# Verify that the packages are registered in Slackware's package database.
for pkg in libgusb colord; do
    if ! is_installed "$pkg"; then
        log "ERROR: $pkg is still not registered as installed; stopping."
        exit 1
    fi
done

# Libraries selected explicitly for XFCE 4.20. glib2 is deliberately excluded
# by slapt-getrc; --ignore-dep is used only for this reviewed operation.
LIBRARIES=(
    glib2
    gobject-introspection
    gtk+3
    gdk-pixbuf2
    gdk-pixbuf2-xlib
    libdisplay-info
    libxfce4windowing
)

# Installed XFCE components only.
PREFIXES=(
    exo
    garcon
    gtk-xfce-engine
    libxfce4ui
    libxfce4util
    thunar
    thunar-volman
    tumbler
    xfce4-panel
    xfce4-session
    xfce4-settings
    xfce4-terminal
    xfdesktop
    xfwm4
    xfconf
)

declare -A INSTALLED=()
for file in /var/log/packages/*; do
    [ -f "$file" ] || continue
    pkg="${file##*/}"
    name="$(printf '%s\n' "$pkg" | sed -E 's/-[0-9].*$//')"
    for prefix in "${PREFIXES[@]}"; do
        if [ "$name" = "$prefix" ] || [[ "$name" == "$prefix"-* ]]; then
            INSTALLED["$name"]=1
        fi
    done
done

mapfile -t XFCE_PACKAGES < <(printf '%s\n' "${!INSTALLED[@]}" | sed '/^$/d' | sort)

log ""
log "Updating repository metadata..."
if ! slapt-get --update 2>&1 | tee -a "$LOG"; then
    log "ERROR: repository update failed."
    exit 1
fi

log ""
log "Selected libraries (including explicitly approved new components):"
printf '  %s\n' "${LIBRARIES[@]}" | tee -a "$LOG"
log ""
log "Installed XFCE packages to upgrade:"
if [ "${#XFCE_PACKAGES[@]}" -gt 0 ]; then
    printf '  %s\n' "${XFCE_PACKAGES[@]}" | tee -a "$LOG"
else
    log "  (none found)"
    exit 1
fi

log ""
log "Simulating the selected library operation..."
SIM_LOG="$(mktemp)" || exit 1
if ! slapt-get --simulate --ignore-dep --install "${LIBRARIES[@]}" 2>&1 | tee "$SIM_LOG" | tee -a "$LOG"; then
    rm -f "$SIM_LOG"
    log "ERROR: library simulation failed."
    exit 1
fi

# Never proceed if the simulation still reports unmet dependencies.
if grep -Eiq 'unmet dependencies|depends: colord|is required by .* and is excluded|cannot find.*depend' "$SIM_LOG"; then
    rm -f "$SIM_LOG"
    log "ERROR: simulation still reports unresolved dependencies. Nothing further will be installed."
    exit 1
fi
rm -f "$SIM_LOG"

log ""
read -r -p "Review the simulation above. Install/update the selected libraries? [y/N] " answer
case "$answer" in
    y|Y) ;;
    *) log "Cancelled."; exit 0 ;;
esac

if ! slapt-get --ignore-dep --install "${LIBRARIES[@]}" 2>&1 | tee -a "$LOG"; then
    log "ERROR: library installation failed. See $LOG"
    exit 1
fi

log ""
log "Simulating upgrade of installed XFCE packages only."
if ! slapt-get --simulate --no-dep --install "${XFCE_PACKAGES[@]}" 2>&1 | tee -a "$LOG"; then
    log "ERROR: XFCE simulation failed. See $LOG"
    exit 1
fi

log ""
read -r -p "Proceed with upgrade of these installed XFCE packages only? [y/N] " answer
case "$answer" in
    y|Y) ;;
    *) log "XFCE upgrade cancelled."; exit 0 ;;
esac

if ! slapt-get --no-dep --install "${XFCE_PACKAGES[@]}" 2>&1 | tee -a "$LOG"; then
    log "ERROR: XFCE upgrade failed. See $LOG"
    exit 1
fi

log ""
log "Operation completed."
log "Log: $LOG"

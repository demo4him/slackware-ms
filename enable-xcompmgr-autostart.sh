#!/bin/sh
# Enable xcompmgr at XFCE session startup for the current user.

set -eu

# Do not change XFCE settings if xcompmgr is unavailable.
if ! command -v xcompmgr >/dev/null 2>&1; then
    printf 'Error: xcompmgr is not installed or not in PATH.\n' >&2
    exit 1
fi

if ! command -v xfconf-query >/dev/null 2>&1; then
    printf 'Error: xfconf-query was not found; cannot disable XFCE compositing.\n' >&2
    exit 1
fi

# Disable XFCE compositing to avoid a conflict with xcompmgr.
if ! xfconf-query --channel=xfwm4 --property=/general/use_compositing --set=false 2>/dev/null; then
    xfconf-query --channel=xfwm4 --property=/general/use_compositing \
        --create --type=bool --set=false
fi

AUTOSTART_DIR="${HOME}/.config/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/xcompmgr.desktop"

mkdir -p "$AUTOSTART_DIR"

cat > "$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=Xcompmgr
Comment=Desktop shadows
Exec=xcompmgr -c -C -t-5 -l-5 -r4 -o.55
Terminal=false
EOF

chmod 644 "$DESKTOP_FILE"
printf 'Xcompmgr autostart enabled: %s\n' "$DESKTOP_FILE"
printf 'Log out and back in for the change to take effect.\n'

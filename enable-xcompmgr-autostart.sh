#!/bin/sh
# Enable xcompmgr at XFCE session startup.
# Installs an XDG autostart entry for the current user.

set -eu

AUTOSTART_DIR="${HOME}/.config/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/xcompmgr.desktop"

mkdir -p "$AUTOSTART_DIR"

cat > "$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=Xcompmgr
Comment=Enable desktop compositing shadows
Exec=sh -c 'xcompmgr -c -C -t-5 -l-5 -r4.2 -o.55'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

chmod 644 "$DESKTOP_FILE"
printf 'Created autostart entry: %s\n' "$DESKTOP_FILE"
printf 'It will run at the next graphical login. Ensure xcompmgr is installed.\n'

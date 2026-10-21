#!/bin/sh
set -e

# Keep the terminal open after completion or failure so the output can be read.
finish() {
    status=$?
    trap - EXIT
    printf '\nExit code: %s\n' "$status"
    printf '%s' 'Press Enter to close this window...'
    read answer || true
    exit "$status"
}
trap finish EXIT

# Thunar custom actions for Slackware 15.0 Stable.
# KISS revision: one root escalation, POSIX sh, no fake progress,
# idempotent helper installation, and a narrower sudoers rule.

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Error: sudo is not available. Run this script as root."
    exit 1
fi

USER_CURRENT=${SUDO_USER:-$(id -un)}
REAL_HOME=$(getent passwd "$USER_CURRENT" | cut -d: -f6)

[ -n "$REAL_HOME" ] || {
    printf '%s\n' "Error: cannot determine the home directory for $USER_CURRENT."
    exit 1
}

UCA_DIR="$REAL_HOME/.config/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"

# Install a small red terminal icon for the root-terminal action.
ICON_DIR="$REAL_HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
cat > "$ICON_DIR/root-terminal.svg" << 'SVG_EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <rect x="3" y="5" width="42" height="38" rx="3" fill="#c62828" stroke="#7f0000" stroke-width="2"/>
  <rect x="7" y="9" width="34" height="30" rx="1" fill="#202124"/>
  <path d="M12 17l6 5-6 5" fill="none" stroke="#ff5252" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M22 28h10" fill="none" stroke="#ff5252" stroke-width="3" stroke-linecap="round"/>
  <circle cx="10" cy="12" r="1" fill="#ff8a80"/>
  <circle cx="14" cy="12" r="1" fill="#ff8a80"/>
  <circle cx="18" cy="12" r="1" fill="#ff8a80"/>
</svg>
SVG_EOF

# Install a matching red folder icon for opening Thunar with administrator privileges.
cat > "$ICON_DIR/root-folder.svg" << 'SVG_EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <path d="M4 11a3 3 0 0 1 3-3h12l4 5h18a3 3 0 0 1 3 3v21a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3z" fill="#c62828" stroke="#7f0000" stroke-width="2" stroke-linejoin="round"/>
  <path d="M4 19h40l-4 18a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3z" fill="#ef5350"/>
  <path d="M24 22v12M18 28h12" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/>
</svg>
SVG_EOF
chown -R "$USER_CURRENT":$(id -gn "$USER_CURRENT") "$REAL_HOME/.local/share/icons"

# Restart Thunar so it reloads uca.xml.
# Gracefully stop the user's Thunar processes, if they are running.
pkill -u "$USER_CURRENT" -x thunar 2>/dev/null || true
pkill -u "$USER_CURRENT" -x Thunar 2>/dev/null || true

printf '%s\n' "[1/4] Installing Thunar helper scripts..."

cat > /usr/bin/suxe << 'EOF'
#!/bin/sh
[ -n "$DISPLAY" ] || export DISPLAY=:0.0
if [ -z "$XAUTHORITY" ]; then
    if [ -n "$SUDO_USER" ]; then
        XAUTHORITY=$(getent passwd "$SUDO_USER" | cut -d: -f6)/.Xauthority
    else
        XAUTHORITY="$HOME/.Xauthority"
    fi
    export XAUTHORITY
fi
exec "$@"
EOF
chmod 755 /usr/bin/suxe

cat > /usr/bin/thunar-desktop-shortcut << 'EOF'
#!/bin/sh
for item in "$@"; do
    name=$(basename "$item")
    shortcut="$HOME/Desktop/$name.desktop"

    {
        printf '%s\n' '[Desktop Entry]'
        printf '%s\n' 'Version=1.0'
        printf '%s\n' 'Type=Application'
        printf 'Name=%s\n' "$name"

        if [ -d "$item" ]; then
            printf 'Exec=thunar %s\n' "\"$item\""
            printf '%s\n' 'Icon=folder'
        else
            printf 'Exec=xdg-open %s\n' "\"$item\""
            printf '%s\n' 'Icon=system-run'
        fi
    } > "$shortcut"

    chmod +x "$shortcut"
done
EOF
chmod 755 /usr/bin/thunar-desktop-shortcut

cat > /usr/bin/thunar-zip-windows << 'EOF'
#!/bin/sh
[ "$#" -gt 0 ] || exit 1

archive_name=$(basename "$1" | sed 's/\.[^.]*$//')
[ -n "$archive_name" ] || archive_name="archive_$(id -un)"

exec zip -r -q "$archive_name.zip" "$@"
EOF
chmod 755 /usr/bin/thunar-zip-windows

cat > /usr/bin/thunar-unzip-windows << 'EOF'
#!/bin/sh
for archive in "$@"; do
    folder=$(basename "$archive" | sed 's/\.[^.]*$//')
    mkdir -p "$folder"
    unzip -q -j -O CP1250 "$archive" -d "$folder"
done
EOF
chmod 755 /usr/bin/thunar-unzip-windows

cat > /usr/bin/thunar-mount-image << 'EOF'
#!/bin/sh
image_path=$1
[ -n "$image_path" ] || exit 1

image_name=$(basename "$image_path")
mount_point="/media/img_${image_name%.*}"

if mountpoint -q "$mount_point"; then
    umount "$mount_point" && rmdir "$mount_point"
    zenity --info --title="Image Unmounted" \
        --text="Successfully unmounted:\n$image_name" \
        --timeout=3 2>/dev/null || true
    exit 0
fi

mkdir -p "$mount_point"

if mount -o loop,ro "$image_path" "$mount_point" 2>/dev/null; then
    suxe thunar "$mount_point" &
else
    rmdir "$mount_point" 2>/dev/null || true
    zenity --error --title="Mount Error" \
        --text="Failed to mount device image:\n$image_name" \
        2>/dev/null || true
    exit 1
fi
EOF
chmod 755 /usr/bin/thunar-mount-image

printf '%s\n' "[2/4] Installing the restricted sudoers rule..."

sudoers_file="/etc/sudoers.d/thunar-$USER_CURRENT"
cat > "$sudoers_file" << EOF
$USER_CURRENT ALL=(ALL) NOPASSWD: /usr/bin/thunar, /usr/bin/thunar-mount-image
EOF
chmod 0440 "$sudoers_file"

# Slackware package actions: run in xterm so output and errors remain visible.
# sudo uses the user's normal policy; no NOPASSWD rule is added for package tools.
cat > /usr/bin/thunar-installpkg << 'EOF'
#!/bin/sh
[ "$#" -gt 0 ] || exit 1
command -v xterm >/dev/null 2>&1 || { printf '%s\n' "Error: xterm is not installed."; exit 1; }
exec xterm -T "Install Slackware Package" -e /bin/sh -c '
printf "%s\n\n" "Running: sudo /sbin/installpkg"
sudo /sbin/installpkg "$@"
status=$?
printf "\nExit status: %s\n" "$status"
if [ "$status" -eq 0 ]; then
    printf "%s\n" "Package installation command completed successfully."
else
    printf "%s\n" "Package installation command failed."
fi
printf "\n%s" "Press Enter to close this window..."
read answer
exit "$status"
' sh "$@"
EOF
chmod 755 /usr/bin/thunar-installpkg

cat > /usr/bin/thunar-removepkg << 'EOF'
#!/bin/sh
[ "$#" -gt 0 ] || {
    xterm -T "Remove Slackware Package" -e /bin/sh -c '
    printf "%s\n" "Right-click an installed package entry to remove it."
    printf "%s\n" "Select the package name or package file in Thunar."
    printf "\n%s" "Press Enter to close..."
    read answer
    '
    exit 1
}
command -v xterm >/dev/null 2>&1 || { printf '%s\n' "Error: xterm is not installed."; exit 1; }

# Thunar passes the selected item's path. Convert a selected package archive
# filename to a Slackware package name, or accept a selected installed-package
# entry only if its basename exactly matches an installed package log.
exec xterm -T "Remove Slackware Package" -e /bin/sh -c '
selected=$1
base=$(basename "$selected")
package=

# If the cursor is on an installed package log in /var/log/packages, use its basename.
if [ "$(dirname "$selected")" = "/var/log/packages" ] && [ -f "$selected" ]; then
    package=$base
else
    # If the selected item is a Slackware package archive, strip its .t?z suffix.
    case "$base" in
        *.t?z|*.T?Z) package=${base%.*} ;;
        *)
            printf "%s\n" "Cannot determine a package name from:"
            printf "%s\n" "$selected"
            printf "%s\n" "Select a package archive (.txz, .tgz, .tbz, .tlz) or an installed package entry in /var/log/packages."
            printf "\n%s" "Press Enter to close..."
            read answer
            exit 1
            ;;
    esac
fi

case "$package" in
    ""|-*|*/*|*" "*)
        printf "%s\n" "Invalid package name: $package"
        printf "\n%s" "Press Enter to close..."
        read answer
        exit 1
        ;;
esac

printf "Selected item: %s\n" "$selected"
printf "Package name: %s\n\n" "$package"
printf "Running: sudo /sbin/removepkg %s\n\n" "$package"
sudo /sbin/removepkg "$package"
status=$?
printf "\nExit status: %s\n" "$status"
if [ "$status" -eq 0 ]; then
    printf "%s\n" "Package removal command completed successfully."
else
    printf "%s\n" "Package removal command failed."
fi
printf "\n%s" "Press Enter to close this window..."
read answer
exit "$status"
' sh "$1"
EOF
chmod 755 /usr/bin/thunar-removepkg

cat > /usr/bin/thunar-upgradepkg << 'EOF'
#!/bin/sh
[ "$#" -gt 0 ] || exit 1
command -v xterm >/dev/null 2>&1 || { printf '%s\n' "Error: xterm is not installed."; exit 1; }
exec xterm -T "Install / Upgrade Slackware Package" -e /bin/sh -c '
printf "%s\n\n" "Running: sudo /sbin/upgradepkg --install-new"
sudo /sbin/upgradepkg --install-new "$@"
status=$?
printf "\nExit status: %s\n" "$status"
if [ "$status" -eq 0 ]; then
    printf "%s\n" "Package installation / upgrade command completed successfully."
else
    printf "%s\n" "Package installation / upgrade command failed."
fi
printf "\n%s" "Press Enter to close this window..."
read answer
exit "$status"
' sh "$@"
EOF
chmod 755 /usr/bin/thunar-upgradepkg

# Run selected scripts with sudo, while keeping output visible in xterm.
cat > /usr/bin/thunar-run-script-sudo << 'EOF'
#!/bin/sh
[ "$#" -gt 0 ] || exit 1
command -v xterm >/dev/null 2>&1 || { printf '%s\n' "Error: xterm is not installed."; exit 1; }

exec xterm -T "Run Script as Root" -e /bin/sh -c '
script=$1
case "$script" in
    *.sh|*.SH) ;;
    *)
        printf "%s\n" "This action is intended for shell scripts (.sh)."
        printf "\n%s" "Press Enter to close this window..."
        read answer
        exit 1
        ;;
esac
[ -f "$script" ] || {
    printf "Script not found: %s\n" "$script"
    printf "\n%s" "Press Enter to close this window..."
    read answer
    exit 1
}
printf "Running as root with sudo: %s\n\n" "$script"
sudo /bin/sh "$script"
status=$?
printf "\nExit status: %s\n" "$status"
if [ "$status" -eq 0 ]; then
    printf "%s\n" "Script completed successfully."
else
    printf "%s\n" "Script failed."
fi
printf "\n%s" "Press Enter to close this window..."
read answer
exit "$status"
' sh "$1"
EOF
chmod 755 /usr/bin/thunar-run-script-sudo

printf '%s\n' "[3/4] Writing Thunar custom actions..."

mkdir -p "$UCA_DIR"

cat > "$UCA_FILE" << 'XML_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
    <icon>utilities-terminal</icon>
    <name>Open Terminal Here</name>
    <unique-id>open-terminal-marius</unique-id>
    <command>xfce4-terminal --working-directory=%f</command>
    <description>Open terminal</description>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>root-folder</icon>
    <name>Open with Administrator Privileges</name>
    <unique-id>open-as-root-suxe</unique-id>
    <command>sudo -H suxe thunar %f</command>
    <description>Open Thunar with administrator privileges</description>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>root-terminal</icon>
    <name>Root Terminal Here</name>
    <unique-id>root-terminal-here-kiss</unique-id>
    <command>xfce4-terminal --disable-server --working-directory=&quot;%f&quot; --command=&quot;sudo -s&quot;</command>
    <description>Open a terminal shell as root in this directory</description>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>system-run</icon>
    <name>Run Script in Terminal</name>
    <unique-id>run-script-terminal-marius</unique-id>
    <command>xfce4-terminal --title="Run: %n" -e "bash -c 'chmod +x %f; %f; echo; echo ----------------------------------------; echo [Slackware 15.0] Execution finished.; echo Press Enter to close...; read -r'"</command>
    <description>Run the script and keep the terminal open</description>
    <patterns>*.sh;*.py;*.pl;*.rc</patterns>
    <text-files/>
    <other-files/>
</action>
<action>
    <icon>system-search</icon>
    <name>Search Files</name>
    <unique-id>search-catfish-bsd</unique-id>
    <command>catfish --path=%f</command>
    <description>Catfish</description>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>user-desktop</icon>
    <name>Create Desktop Shortcut</name>
    <unique-id>desktop-shortcut-bsd</unique-id>
    <command>thunar-desktop-shortcut %F</command>
    <description>Shortcut</description>
    <patterns>*</patterns>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
</action>
<action>
    <icon>package-x-generic</icon>
    <name>Compress to ZIP (Windows Friendly)</name>
    <unique-id>compress-zip-windows</unique-id>
    <command>thunar-zip-windows %F</command>
    <description>Zip</description>
    <patterns>*</patterns>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
</action>
<action>
    <icon>package-x-generic</icon>
    <name>Extract ZIP (Windows Friendly)</name>
    <unique-id>extract-zip-windows</unique-id>
    <command>thunar-unzip-windows %F</command>
    <description>Unzip</description>
    <patterns>*.zip;*.ZIP</patterns>
    <other-files/>
</action>
<action>
    <icon>media-optical</icon>
    <name>Mount/Unmount Device Image</name>
    <unique-id>thunar-loop-mount-marius</unique-id>
    <command>sudo -H thunar-mount-image %f</command>
    <description>Mount or Unmount standard ISO and IMG device containers automatically</description>
    <patterns>*.iso;*.ISO;*.img;*.IMG</patterns>
    <other-files/>
</action>
<action>
    <icon>package-x-generic</icon>
    <name>Install package</name>
    <unique-id>slackware-installpkg-kiss</unique-id>
    <command>thunar-installpkg %F</command>
    <description>Install selected Slackware package files with sudo</description>
    <patterns>*.t?z;*.T?Z;*.txz;*.tgz;*.tbz;*.tlz;*.TXZ;*.TGZ;*.TBZ;*.TLZ</patterns>
    <other-files/>
</action>
<action>
    <icon>edit-delete</icon>
    <name>Remove package</name>
    <unique-id>slackware-removepkg-kiss</unique-id>
    <command>thunar-removepkg %f</command>
    <description>Remove the selected Slackware package or package archive with sudo</description>
    <patterns>*.t?z;*.T?Z;*.txz;*.tgz;*.tbz;*.tlz;*.TXZ;*.TGZ;*.TBZ;*.TLZ;*</patterns>
    <directories/>
    <other-files/>
</action>
<action>
    <icon>system-software-update</icon>
    <name>Install / upgrade package</name>
    <unique-id>slackware-upgradepkg-kiss</unique-id>
    <command>thunar-upgradepkg %F</command>
    <description>Run upgradepkg --install-new on selected Slackware package files with sudo</description>
    <patterns>*.t?z;*.T?Z;*.txz;*.tgz;*.tbz;*.tlz;*.TXZ;*.TGZ;*.TBZ;*.TLZ</patterns>
    <other-files/>
</action>
<action>
    <icon>utilities-terminal</icon>
    <name>Run Script as Root</name>
    <unique-id>run-script-sudo-kiss</unique-id>
    <command>thunar-run-script-sudo %f</command>
    <description>Execute the selected shell script with sudo in xterm</description>
    <patterns>*.sh;*.SH</patterns>
    <text-files/>
    <other-files/>
</action>
</actions>
XML_EOF

chown "$USER_CURRENT":$(id -gn "$USER_CURRENT") "$UCA_FILE"

printf '%s\n' "[4/4] Thunar setup completed successfully."
printf '%s\n' "Restart Thunar manually if the custom actions do not appear."

exit 0

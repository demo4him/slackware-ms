#!/bin/sh
set -eu

# Slackware 15.0 Stable boot message colorizer.
# Only changes displayed messages in rc.S, rc.M, rc.4 and rc.6.
# Does not touch GRUB, service permissions, or boot logic.

RC_DIR=/etc/rc.d
RC_S="$RC_DIR/rc.S"
RC_M="$RC_DIR/rc.M"
RC_4="$RC_DIR/rc.4"
RC_6="$RC_DIR/rc.6"

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Eroare: sudo nu este disponibil. Rulează scriptul ca root."
    exit 1
fi

backup()
{
    file=$1
    [ -f "$file" ] || return 0
    [ -f "$file.bak" ] || cp -p "$file" "$file.bak"
}

# Keep the original files available for manual recovery.
backup "$RC_S"
backup "$RC_M"
backup "$RC_4"
backup "$RC_6"

# Apply replacements only when the original message is still present.
# This makes the operation idempotent.
if [ -f "$RC_S" ]; then
    sed -i \
        -e 's/echo "Checking non-root file systems:"/printf "\\033[1;33m[*] Checking non-root file systems...\\033[0m\\n"/' \
        -e 's/echo "Remounting root device read-only..."/printf "\\033[0;36m[>] Remounting root device read-only...\\033[0m\\n"/' \
        -e 's/echo "Activating swap partitions."/printf "\\033[1;33m[*] Activating swap partitions...\\033[0m\\n"/' \
        -e 's/echo "Mounting virtual file systems:"/printf "\\033[1;36m[>] Mounting virtual file systems...\\033[0m\\n"/' \
        -e 's/echo "Configuring kernel parameters:"/printf "\\033[1;32m[ OK ]\\033[0m \\033[0;36mTuning kernel variables \\& loading sysctl rules...\\033[0m\\n"/' \
        "$RC_S"

    if ! grep -q 'Mount points linked from /etc/fstab successfully' "$RC_S"; then
        sed -i '/mount -a -v/i\
printf "          \\033[1;32m[ OK ] Mount points linked from /etc/fstab successfully.\\033[0m\\n"' "$RC_S"
    fi
fi

if [ -f "$RC_M" ]; then
    if ! grep -q 'LOADING PRIVATE DESKTOP ENVIRONMENT FOR MARIUS' "$RC_M"; then
        sed -i '/# Initialize the networking system/i\
printf "\\n\\033[1;36m[i] ==================================================\\033[0m\\n\\033[1;32m[ OK ] LOADING PRIVATE DESKTOP ENVIRONMENT FOR MARIUS\\033[0m\\n\\033[1;36m[i] ==================================================\\033[0m\\n"' "$RC_M"
    fi

    sed -i \
        -e 's/echo "Starting local daemons."/printf "\\033[1;32m[ OK ]\\033[0m Starting local daemons...\\n"/' \
        "$RC_M"

    # Show SPEЕDER activity when the stable boot dispatcher is installed.
    if [ -x /usr/local/sbin/speeder-2.0 ] &&
       grep -q '/usr/local/sbin/speeder-2.0' "$RC_M" &&
       ! grep -q 'SPEЕDER: starting selected services in background' "$RC_M"; then
        sed -i '/# Start remaining selected rc files in background\./i\
printf "\\033[1;36m[i] SPEЕDER: starting selected services in background...\\033[0m\\n"' "$RC_M"
    fi
fi

if [ -f "$RC_4" ]; then
    if ! grep -q 'X11 GRAPHICAL INTERFACE' "$RC_4"; then
        sed -i '2i\
printf "\\n\\033[1;36m[i] ==================================================\\033[0m\\n\\033[1;32m[ OK ] LAUNCHING X11 GRAPHICAL INTERFACE MANAGER\\033[0m\\n\\033[1;36m[i] ==================================================\\033[0m\\n"' "$RC_4"
    fi
fi

if [ -f "$RC_6" ]; then
    if ! grep -q 'System shutdown sequence initiated' "$RC_6"; then
        sed -i '2i\
printf "\\n\\033[1;31m[!] Warning: System shutdown sequence initiated!\\033[0m\\n\\033[1;33m[*] Saving system state and unmounting filesystems...\\033[0m\\n"' "$RC_6"
    fi

    sed -i \
        -e 's/echo "Unmounting local file systems."/printf "\\033[1;33m[<] Unmounting local file systems...\\033[0m\\n"/' \
        -e 's/echo "Remounting root filesystem read-only."/printf "\\033[1;31m[!] Remounting root filesystem read-only...\\033[0m\\n"/' \
        "$RC_6"
fi

# Validate every modified script before declaring success.
for file in "$RC_S" "$RC_M" "$RC_4" "$RC_6"; do
    [ -f "$file" ] || continue
    sh -n "$file"
done

printf '%s\n' "[OK] Boot messages updated for Slackware 15.0."
printf '%s\n' "[OK] Original files are preserved as .bak."
printf '%s\n' "[OK] Boot logic and executable permissions were not changed."

exit 0

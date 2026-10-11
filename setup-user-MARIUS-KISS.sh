#!/bin/sh
set -eu

# Slackware 15.0 Stable user setup.
# KISS: one root escalation, POSIX sh, consistent username handling.
# Creates the user, configures wheel access, optional graphical runlevel,
# and optional passwordless sudo/polkit for the created user.

PATH=/usr/local/bin:/usr/bin:/bin:/usr/games:/sbin:/usr/sbin
export PATH

# Ensure Slackware /etc/profile includes /sbin and /usr/sbin after /usr/games.
if [ -f /etc/profile ]; then
    sed -i 's|^PATH="/usr/local/bin:/usr/bin:/bin:/usr/games"$|PATH="/usr/local/bin:/usr/bin:/bin:/usr/games:/sbin:/usr/sbin"|' /etc/profile
fi

BACKTITLE="Slackware 15.0 Stable Setup"

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Error: sudo is not available. Run the script as root."
    exit 1
fi

command -v dialog >/dev/null 2>&1 || {
    printf '%s\n' "Error: dialog is not installed."
    exit 1
}

dialog --backtitle "$BACKTITLE" \
    --title "Slackware 15.0 Setup" \
    --msgbox "Create and configure a user account." 8 55

while :; do
    username=$(dialog --backtitle "$BACKTITLE" \
        --title "User Account" \
        --stdout \
        --inputbox "New username:" 10 60) || exit 1

    case "$username" in
        ''|*[!a-zA-Z0-9_-]*)
            dialog --backtitle "$BACKTITLE" \
                --title "Input Error" \
                --msgbox "Use only letters, digits, '_' or '-'." 8 55
            continue
            ;;
    esac

    if id "$username" >/dev/null 2>&1; then
        dialog --backtitle "$BACKTITLE" \
            --title "User Exists" \
            --msgbox "User '$username' already exists." 8 55
        continue
    fi

    break
done

# Slackware already provides the wheel group on a normal installation.
# Create it only if a non-standard installation does not have it.
if ! getent group wheel >/dev/null 2>&1; then
    groupadd wheel
fi

useradd -m -k /etc/skel -g users \
    -G wheel,floppy,audio,video,cdrom,plugdev,power,netdev,lp,scanner \
    -s /bin/bash "$username"

while :; do
    pass1=$(dialog --backtitle "$BACKTITLE" \
        --title "Password" \
        --stdout --insecure \
        --passwordbox "Password for '$username':" 10 60) || exit 1

    pass2=$(dialog --backtitle "$BACKTITLE" \
        --title "Password" \
        --stdout --insecure \
        --passwordbox "Re-enter password:" 10 60) || exit 1

    if [ -n "$pass1" ] && [ "$pass1" = "$pass2" ]; then
        printf '%s:%s\n' "$username" "$pass1" | chpasswd
        break
    fi

    dialog --backtitle "$BACKTITLE" \
        --title "Password Error" \
        --msgbox "Passwords do not match or are empty." 8 55
done

# Optional passwordless sudo for the created user.
# Kept as an explicit choice instead of modifying /etc/sudoers directly.
if dialog --backtitle "$BACKTITLE" \
    --title "Sudo" \
    --yesno "Grant passwordless sudo to user '$username'?" 9 60; then

    if command -v visudo >/dev/null 2>&1; then
        printf '%s\n' \
            "$username ALL=(ALL:ALL) NOPASSWD: ALL" \
            > "/etc/sudoers.d/$username"
        chmod 0440 "/etc/sudoers.d/$username"
        if ! visudo -c >/dev/null 2>&1; then
            rm -f "/etc/sudoers.d/$username"
            dialog --backtitle "$BACKTITLE" \
                --title "Sudo Error" \
                --msgbox "The sudo configuration failed validation. The change was cancelled." 9 60
            exit 1
        fi
    else
        dialog --backtitle "$BACKTITLE" \
            --title "Sudo Error" \
            --msgbox "visudo is not available. Sudo configuration was skipped." 8 55
    fi
fi

# Optional polkit rule for this user only.
POLKIT_DIR=/etc/polkit-1/rules.d
if [ -d "$POLKIT_DIR" ] && dialog --backtitle "$BACKTITLE" \
    --title "Polkit" \
    --yesno "Allow polkit actions without authentication for '$username'?" 9 60; then

    POLKIT_FILE="$POLKIT_DIR/49-$username-nopasswd.rules"

    cat > "$POLKIT_FILE" << EOF
polkit.addRule(function(action, subject) {
    if (subject.user == "$username") {
        return polkit.Result.YES;
    }
});
EOF
    chmod 0644 "$POLKIT_FILE"
    chown root:root "$POLKIT_FILE"
fi

# Optional graphical default runlevel.
if [ -f /etc/inittab ] &&
   dialog --backtitle "$BACKTITLE" \
    --title "Default Runlevel" \
    --yesno "Boot by default into runlevel 4 (graphical)?" 10 60; then

    sed -i 's/^[[:space:]]*id:3:initdefault:/id:4:initdefault:/' /etc/inittab
fi

if dialog --backtitle "$BACKTITLE" \
    --title "Completed" \
    --yesno "User setup is complete.\n\nReboot the system now?" 10 60; then
    reboot
else
    dialog --backtitle "$BACKTITLE" \
        --title "Completed" \
        --msgbox "Setup is complete. Reboot manually when you wish." 8 55
fi

exit 0

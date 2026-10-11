#!/bin/sh
set -e

# Move /home to /dev/sdb1 on Slackware 15.0 Stable.
# Target-specific by design: /dev/sdb1 -> /home.

DEVICE=/dev/sdb1
TMP_MOUNT=/mnt/tmp
HOME_MOUNT=/home
FSTAB=/etc/fstab

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Eroare: sudo nu este disponibil. Rulează scriptul ca root."
    exit 1
fi

if ! command -v dialog >/dev/null 2>&1; then
    printf '%s\n' "Eroare: dialog nu este instalat."
    exit 1
fi

confirm()
{
    dialog --title "$1" --yesno "$2" 10 60
}

message()
{
    dialog --title "$1" --msgbox "$2" 8 55
}

# STEP 1: Mount the target partition temporarily.
if confirm "STEP 1: PREPARATION" \
    "Create $TMP_MOUNT and mount $DEVICE there?"; then

    mkdir -p "$TMP_MOUNT"

    if mount "$DEVICE" "$TMP_MOUNT"; then
        message "STATUS" "$DEVICE mounted successfully on $TMP_MOUNT."
    else
        message "ERROR" "Could not mount $DEVICE."
        exit 1
    fi
else
    message "ABORTED" "Step 1 was cancelled."
    exit 1
fi

# STEP 2: Copy the existing /home.
if confirm "STEP 2: DATA COPY" \
    "Copy the contents of /home/ to $TMP_MOUNT with rsync?"; then

    printf '%s\n' "[+] Copying /home/ to $TMP_MOUNT..."
    rsync -avx /home/ "$TMP_MOUNT/"
    message "STATUS" "The /home data copy completed successfully."
else
    message "ABORTED" "Data migration was cancelled."
    umount "$TMP_MOUNT" 2>/dev/null || true
    exit 1
fi

# STEP 3: Verify the target as /home.
if confirm "STEP 3: VALIDATION" \
    "Temporarily mount $DEVICE directly on /home to verify the copied data?"; then

    mount "$DEVICE" "$HOME_MOUNT"
    message "STATUS" \
        "$DEVICE is now mounted on /home.\n\nCheck the data, then press OK to unmount it."
    umount "$HOME_MOUNT"
else
    message "ABORTED" "Validation was cancelled."
    umount "$TMP_MOUNT" 2>/dev/null || true
    exit 1
fi

# The temporary mount is no longer needed.
umount "$TMP_MOUNT"

# STEP 4: Destructive operation.
if confirm "WARNING: DESTRUCTIVE OPERATION" \
    "Delete the old contents of /home now?\n\nThis permanently removes the old copies from the system disk.\n\nProceed only after verifying the new partition."; then

    if mountpoint -q "$HOME_MOUNT"; then
        message "BLOCKED" \
            "The new $DEVICE is still mounted on /home.\n\nDeletion has been cancelled."
        exit 1
    fi

    rm -rf "$HOME_MOUNT"/*
    rm -rf "$HOME_MOUNT"/.[!.]* "$HOME_MOUNT"/..?* 2>/dev/null || true

    message "STATUS" "Old /home contents were removed."
else
    message "PRESERVED" "The old /home contents were left unchanged."
    exit 1
fi

# STEP 5: Add the persistent mount.
if confirm "STEP 5: /etc/fstab" \
    "Add $DEVICE as the persistent /home mount in /etc/fstab?"; then

    if ! grep -q '^[[:space:]]*/dev/sdb1[[:space:]]\+/home[[:space:]]' "$FSTAB"; then
        printf '%s\n' \
            '/dev/sdb1        /home            ext4        defaults         1   2' \
            >> "$FSTAB"
        message "STATUS" "/etc/fstab updated."
    else
        message "INFO" "$DEVICE -> /home is already present in /etc/fstab."
    fi
else
    message "ABORTED" "The /etc/fstab change was skipped."
fi

if confirm "COMPLETED" \
    "The /home migration is complete.\n\nReboot Slackware now?"; then
    reboot
else
    printf '%s\n' "[OK] Migration completed. Reboot manually when convenient."
fi

exit 0

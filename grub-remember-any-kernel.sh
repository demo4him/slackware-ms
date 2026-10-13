#!/bin/bash
# Slackware 15.0 / GRUB 2.06
# Remember the kernel selected manually from the GRUB menu, including Advanced options.
# Does not modify Kernel_Generic.sh or remove any kernel.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: run as root: su - then bash /path/to/grub-remember-any-kernel.sh"
  exit 1
fi

DEFAULTS=/etc/default/grub
CFG=/boot/grub/grub.cfg
GRUBENV=/boot/grub/grubenv

for cmd in grub-mkconfig grub-editenv; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: command not found: $cmd"; exit 1; }
done
[[ -f "$DEFAULTS" ]] || { echo "Error: missing $DEFAULTS"; exit 1; }
[[ -f "$CFG" ]] || { echo "Error: missing $CFG"; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/root/grub-remember-backup-$STAMP"
mkdir -p "$BACKUP_DIR"
cp -a "$DEFAULTS" "$BACKUP_DIR/default-grub"
cp -a "$CFG" "$BACKUP_DIR/grub.cfg"
if [[ -f "$GRUBENV" ]]; then cp -a "$GRUBENV" "$BACKUP_DIR/grubenv"; fi

echo "Backup created: $BACKUP_DIR"

# Keep one authoritative setting for each variable; preserve all other settings.
TMP=$(mktemp)
awk '
  ! /^[[:space:]]*#?[[:space:]]*GRUB_DEFAULT=/ &&
  ! /^[[:space:]]*#?[[:space:]]*GRUB_SAVEDEFAULT=/ { print }
' "$DEFAULTS" > "$TMP"
printf '\nGRUB_DEFAULT=saved\nGRUB_SAVEDEFAULT=true\n' >> "$TMP"
cat "$TMP" > "$DEFAULTS"
rm -f "$TMP"

# Regenerate GRUB configuration using the same command as the kernel script.
grub-mkconfig -o "$CFG"

# Verify saved-entry support without assuming any specific kernel versions.
grep -Eq 'saved_entry' "$CFG" || {
  echo "Error: generated configuration does not appear to support saved_entry."
  echo "Backup: $BACKUP_DIR"
  exit 1
}

# Do not overwrite an existing saved choice. If none exists, GRUB will use its
# configured fallback until the user selects a menu entry.
SAVED=$(grub-editenv "$GRUBENV" list 2>/dev/null | sed -n 's/^saved_entry=//p' || true)
if [[ -z "$SAVED" ]]; then
  echo "No saved_entry is set yet. At the next boot, select any kernel from the GRUB menu."
else
  echo "Current saved_entry: $SAVED"
fi

echo
echo "Configuration complete. GRUB is configured to remember the selected menu entry."
echo "At reboot, select the desired kernel, including one under Advanced options if available."
echo "After selecting it once, GRUB should use that entry on subsequent boots."
echo "No specific kernel version is required; installed entries are handled generically."
echo
echo "If the selection is not remembered, check whether grubenv is writable with:"
echo "  grub-editenv $GRUBENV list"
echo "Backup: $BACKUP_DIR"

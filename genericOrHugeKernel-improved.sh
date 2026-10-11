#!/bin/bash
# Slackware KISS - Generic / Huge Kernel Detector
# Detects the running kernel type using its actual kernel configuration.

set -uo pipefail

KERNEL="$(uname -r)"
CONFIG=""

# Prefer the config belonging to the running kernel.
if [[ -r "/boot/config-$KERNEL" ]]; then
    CONFIG="/boot/config-$KERNEL"
elif [[ -r /proc/config.gz ]] && command -v zcat >/dev/null 2>&1; then
    CONFIG="/proc/config.gz"
else
    echo "ERROR: Nu găsesc configurația kernelului $KERNEL."
    echo "Cautat: /boot/config-$KERNEL sau /proc/config.gz"
    exit 1
fi

get_config() {
    local key="$1"
    if [[ "$CONFIG" == "/proc/config.gz" ]]; then
        zgrep -m1 "^${key}=" /proc/config.gz 2>/dev/null | cut -d= -f2
    else
        grep -m1 "^${key}=" "$CONFIG" 2>/dev/null | cut -d= -f2
    fi
}

show_value() {
    local key="$1"
    local value
    value="$(get_config "$key")"
    [[ -n "$value" ]] || value="not set"
    printf '  %-24s = %s\n' "$key" "$value"
}

# The most useful Slackware distinction is how core filesystem/storage
# support is built: Generic kernels normally use modules, while Huge kernels
# build many of these directly into the kernel.
EXT4="$(get_config CONFIG_EXT4_FS)"
XFS="$(get_config CONFIG_XFS_FS)"
BTRFS="$(get_config CONFIG_BTRFS_FS)"
SCSI="$(get_config CONFIG_SCSI)"
SATA="$(get_config CONFIG_ATA)"
USB_STORAGE="$(get_config CONFIG_USB_STORAGE)"

GENERIC_SCORE=0
HUGE_SCORE=0

for value in "$EXT4" "$XFS" "$BTRFS" "$SCSI" "$SATA" "$USB_STORAGE"; do
    case "$value" in
        m) GENERIC_SCORE=$((GENERIC_SCORE + 1)) ;;
        y) HUGE_SCORE=$((HUGE_SCORE + 1)) ;;
    esac
done

# EXT4 is especially useful for the normal Slackware Generic configuration.
if [[ "$EXT4" == "m" ]]; then
    GENERIC_SCORE=$((GENERIC_SCORE + 3))
elif [[ "$EXT4" == "y" ]]; then
    HUGE_SCORE=$((HUGE_SCORE + 3))
fi

if (( GENERIC_SCORE >= HUGE_SCORE + 3 )); then
    TYPE="GENERIC"
elif (( HUGE_SCORE >= GENERIC_SCORE + 3 )); then
    TYPE="HUGE"
else
    TYPE="CUSTOM / NECUNOSCUT"
fi

echo "=============================================="
echo " Slackware Kernel Detector"
echo "=============================================="
echo
printf 'Kernel pornit : %s\n' "$KERNEL"
printf 'Configurație  : %s\n' "$CONFIG"
echo

echo "Indicatori principali:"
show_value CONFIG_EXT4_FS
show_value CONFIG_XFS_FS
show_value CONFIG_BTRFS_FS
show_value CONFIG_SCSI
show_value CONFIG_ATA
show_value CONFIG_USB_STORAGE
echo

echo "----------------------------------------------"
printf 'Rezultat      : %s\n' "$TYPE"
printf 'Scor Generic  : %d\n' "$GENERIC_SCORE"
printf 'Scor Huge     : %d\n' "$HUGE_SCORE"
echo "----------------------------------------------"

echo
case "$TYPE" in
    GENERIC)
        echo "OK: configurația seamănă cu un kernel Slackware Generic."
        ;;
    HUGE)
        echo "INFO: configurația seamănă cu un kernel Slackware Huge."
        ;;
    *)
        echo "INFO: configurația nu permite o identificare sigură Generic/Huge."
        echo "      Probabil este un kernel custom sau o configurație diferită."
        ;;
esac

sleep 8

echo "DONE!"
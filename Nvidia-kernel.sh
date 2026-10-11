#!/bin/sh
#
# Auto–rebuild NVIDIA driver after kernel upgrade

LOG="/var/log/nvidia-rebuild.log"
echo "=== NVIDIA rebuild started at $(date) ===" >> "$LOG"

# Determine kernel version just installed
KVER="$1"
if [ -z "$KVER" ]; then
    KVER=$(uname -r)
fi

echo "Kernel version: $KVER" >> "$LOG"

# If installed via the NVIDIA .run file:
if [ -x /usr/bin/nvidia-installer ]; then
    echo "Rebuilding NVIDIA via nvidia-installer..." >> "$LOG"
    /usr/bin/nvidia-installer --kernel-name="$KVER" -s >> "$LOG" 2>&1
    exit 0
fi

# If installed as SlackBuild package (nvidia-driver + nvidia-kernel):
if [ -d /usr/src/nvidia-driver ]; then
    echo "Rebuilding via SlackBuild..." >> "$LOG"
    cd /usr/src/nvidia-kernel* || exit 1
    sh nvidia-kernel.SlackBuild >> "$LOG" 2>&1
    upgradepkg --install-new /tmp/nvidia-kernel-*.txz >> "$LOG" 2>&1
    exit 0
fi

echo "No NVIDIA installer found. Nothing done." >> "$LOG"
exit 0

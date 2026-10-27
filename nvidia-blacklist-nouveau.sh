
#!/bin/bash
#
# NVIDIA - Disable Nouveau
# Slackware 15.0 x86_64
#

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

CONF="/etc/modprobe.d/nvidia-blacklist.conf"

if [ -f "$CONF" ]; then
    echo "Nouveau blacklist configuration already exists:"
    echo "$CONF"
else
    cat > "$CONF" <<'EOF'
# Disable Nouveau for the proprietary NVIDIA driver
blacklist nouveau
options nouveau modeset=0
EOF
    echo "Nouveau has been blacklisted successfully."
fi

echo
echo "Configuration:"
cat "$CONF"

echo
echo "IMPORTANT:"
echo "Rebuild the initrd if it contains Nouveau,"
echo "then reboot before installing the NVIDIA driver."
echo
echo "Completed successfully."

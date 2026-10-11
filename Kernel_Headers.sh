#!/bin/sh
#
# Kernel-External-Modules-Setup.sh
# Slackware 15.0 KISS
#
# Prepare an existing kernel source tree for generic external-module builds.
# The script is NOT NVIDIA-specific and does not install any driver.
#
# If /usr/src/linux-$KERNEL_VERSION already exists, it is used as-is.
# No download is performed in that case.
#

PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH

SRCBASE=/usr/src

die()
{
    echo "ERROR: $*"
    exit 1
}

pause()
{
    printf "\nPress Enter to continue..."
    read dummy
}

[ "$(id -u)" -eq 0 ] || die "Run this script as root."

clear
echo "=================================================="
echo " Kernel External Modules Setup - Slackware KISS"
echo "=================================================="
echo
echo "Prepares a kernel source tree for external modules."
echo "Generic: NVIDIA, VirtualBox, DKMS, Wi-Fi, etc."
echo

# Select the kernel version interactively.
# No kernel version is hardcoded in the script.
command -v dialog >/dev/null 2>&1 || die "The 'dialog' command is required."

while :; do
    KERNEL_VERSION=$(dialog --stdout \
        --title "Kernel External Modules Setup" \
        --inputbox "Enter the kernel version:\n\nExample: 6.12.111" \
        10 55) || exit 1

    KERNEL_VERSION=$(printf '%s' "$KERNEL_VERSION" | tr -d '[:space:]')

    case "$KERNEL_VERSION" in
        5.[0-9]*|6.[0-9]*) break ;;
        *)
            dialog --title "Invalid Kernel Version" \
                --msgbox "Invalid kernel version:\n\n$KERNEL_VERSION\n\nUse a version such as 5.x.y or 6.x.y." \
                9 60
            ;;
    esac
done

clear

SRC="$SRCBASE/linux-$KERNEL_VERSION"
MODDIR="/lib/modules/$KERNEL_VERSION"

echo
echo "Kernel version : $KERNEL_VERSION"
echo "Source         : $SRC"
echo "Modules        : $MODDIR"
echo

if [ -d "$SRC" ]; then
    echo "Kernel source found."
    echo "No download required."
else
    echo "Kernel source was not found."
    echo "Downloading linux-$KERNEL_VERSION from kernel.org..."

    cd "$SRCBASE" || die "Cannot enter $SRCBASE."

    case "$KERNEL_VERSION" in
        5.*) KMAJOR=5 ;;
        6.*) KMAJOR=6 ;;
    esac

    ARCHIVE="linux-$KERNEL_VERSION.tar.xz"
    URL="https://cdn.kernel.org/pub/linux/kernel/v${KMAJOR}.x/$ARCHIVE"

    wget "$URL" || die "Kernel source download failed."
    tar -xJf "$ARCHIVE" || die "Kernel source extraction failed."

    [ -d "$SRC" ] || die "Expected source directory was not created."
fi

cd "$SRC" || die "Cannot enter kernel source tree."

[ -f Makefile ] || die "This does not look like a Linux kernel source tree."

if [ ! -f .config ]; then
    die "No .config found in $SRC.
This script will not invent or copy a configuration.
Build/prepare the kernel first."
fi

echo
echo "Using existing kernel configuration:"
echo "  $SRC/.config"
echo

echo "Running: make olddefconfig"
make olddefconfig || die "make olddefconfig failed."

echo
echo "Running: make modules_prepare"
make modules_prepare || die "make modules_prepare failed."

echo
echo "Preparing /lib/modules/$KERNEL_VERSION"

mkdir -p "$MODDIR" || die "Cannot create $MODDIR."

if [ -e "$MODDIR/build" ] && [ ! -L "$MODDIR/build" ]; then
    echo "WARNING: $MODDIR/build exists and is not a symbolic link."
    echo "Leaving it untouched."
else
    rm -f "$MODDIR/build"
    ln -s "$SRC" "$MODDIR/build" || die "Cannot create build link."
fi

if [ -e "$MODDIR/source" ] && [ ! -L "$MODDIR/source" ]; then
    echo "WARNING: $MODDIR/source exists and is not a symbolic link."
    echo "Leaving it untouched."
else
    rm -f "$MODDIR/source"
    ln -s "$SRC" "$MODDIR/source" || die "Cannot create source link."
fi

echo
echo "=================================================="
echo " Verification"
echo "=================================================="
echo
echo "Kernel source:"
echo "  $SRC"
echo
echo "build:"
ls -ld "$MODDIR/build"
echo
echo "source:"
ls -ld "$MODDIR/source"
echo
echo "modules_prepare completed successfully."
echo
echo "The source tree is now ready for generic"
echo "external-module compilation."
echo
echo "No driver was installed or configured."
sleep 5
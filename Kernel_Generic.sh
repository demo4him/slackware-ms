#!/bin/bash
# Slackware 15.0 - KISS Kernel Builder (V7.1.0-TTY1-FINAL)
# TTY1-Safe Dialog UI + Gauge Bar + Max Storage & File Systems Protection.
set -uo pipefail

ROOT_DEV=""
INITRD_OUT="/boot/initrd.gz"

[[ $EUID -eq 0 ]] || { echo "ERROR: Must be run as root (sudo)."; exit 1; }
command -v dialog >/dev/null 2>&1 || { echo "ERROR: 'dialog' utility is required."; exit 1; }

# --- TTY1-SAFE DIALOG FUNCTIONS ---

get_kernel_version() {
  local KERNEL_INDEX=""
  local MENU_ARGS=()
  local RELEASE_LIST=()
  local choice=""
  local manual_version=""

  # kernel.org publishes the current release information as JSON.
  # Stable and Longterm kernels are shown; RC/development releases are ignored.
  if command -v wget >/dev/null 2>&1; then
    KERNEL_INDEX=$(wget -qO- --timeout=8 \
      "https://www.kernel.org/releases.json" 2>/dev/null || true)
  fi

  if [[ -n "$KERNEL_INDEX" ]] && command -v awk >/dev/null 2>&1; then
    mapfile -t RELEASE_LIST < <(
      printf '%s\n' "$KERNEL_INDEX" |
      awk '
        /"moniker":/ {
          line=$0
          sub(/.*"moniker": "/, "", line)
          sub(/".*/, "", line)
          type=line
        }

        /"version":/ {
          line=$0
          sub(/.*"version": "/, "", line)
          sub(/".*/, "", line)
          version=line

          if ((type == "stable" || type == "longterm") &&
              version !~ /-rc/) {
            print version "|" type
          }
        }
      '
    )
  fi

  # Build dialog menu.
  local version type
  for entry in "${RELEASE_LIST[@]}"; do
    version="${entry%%|*}"
    type="${entry#*|}"

    if [[ "$type" == "stable" ]]; then
      MENU_ARGS+=("$version" "Stable")
    else
      MENU_ARGS+=("$version" "Longterm")
    fi
  done

  MENU_ARGS+=("MANUAL" "Enter version manually")

  if ((${#MENU_ARGS[@]} > 2)); then
    choice=$(dialog --title "Kernel Version" \
      --menu "Select the Linux kernel version:" 18 65 10 \
      "${MENU_ARGS[@]}" 3>&1 1>&2 2>&3) || exit 0

    if [[ "$choice" == "MANUAL" ]]; then
      manual_version=$(dialog --title "Kernel Version" \
        --inputbox \
        "Enter the target Linux kernel version (e.g., 6.12.112):" \
        8 65 "" 3>&1 1>&2 2>&3) || exit 0
      VERSION="$manual_version"
    else
      VERSION="$choice"
    fi
  else
    # Offline/error fallback: preserve the original manual workflow.
    manual_version=$(dialog --title "Kernel Version" \
      --inputbox \
      "Kernel versions could not be retrieved.\n\nEnter the target Linux kernel version (e.g., 6.12.112):" \
      9 70 "6.12.112" 3>&1 1>&2 2>&3) || exit 0
    VERSION="$manual_version"
  fi

  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    dialog --title "Error" --msgbox \
      "Invalid kernel version format. Exiting." 6 50
    exit 1
  }
}

get_cpu_cores() {
  local default_cores
  default_cores=$(nproc)
  CORES=$(dialog --title "CPU Cores (-j option)" --inputbox "Enter number of cores for parallel compilation (make -j):\nLeave default for max speed, or lower it to control temps." 9 65 "$default_cores" 3>&1 1>&2 2>&3)
  [[ "$CORES" =~ ^[1-9][0-9]*$ ]] || CORES=$default_cores
}

select_root_partition() {
  local dialog_args=()
  while read -r name size; do
    dialog_args+=("/dev/$name" "$size" "off")
  done < <(lsblk -no NAME,SIZE,TYPE -l | grep 'part')

  if [ ${#dialog_args[@]} -eq 0 ]; then
    ROOT_DEV="/dev/sda3"
    return
  fi

  ROOT_DEV=$(dialog --title "Select Root Partition" --radiolist \
    "Choose the partition where your Slackware root (/) is installed:" 15 70 8 \
    "${dialog_args[@]}" 3>&1 1>&2 2>&3)

  [[ -n "$ROOT_DEV" ]] || ROOT_DEV="/dev/sda3"
}

select_profile() {
  PROFILE=$(dialog --title "Kernel Profile Selection" --menu \
    "Choose your target optimization preset:" 12 75 3 \
    "1" "Standard Slackware Generic Profile" \
    "2" "Optimized Desktop (Voluntary Preemption + Multimedia)" 3>&1 1>&2 2>&3)
  
  [[ -n "$PROFILE" ]] || exit 0
}

select_bootloader() {
  BOOT_CHOICE=$(dialog --title "Bootloader Configuration" --menu \
    "Select your active system bootloader to update boot entries:" 12 65 3 \
    "1" "GRUB (runs grub-mkconfig)" \
    "2" "eliloconfig (for UEFI systems)" \
    "3" "lilo (for Legacy BIOS systems)" 3>&1 1>&2 2>&3)
}

# --- EXECUTIVE WORKFLOW ---

get_kernel_version
get_cpu_cores
select_root_partition
select_profile

dialog --title "Ready to Build" --yesno "Configuration complete!\n\nKernel: $VERSION\nCores to use: $CORES\nRoot Device: $ROOT_DEV\nProfile: $PROFILE\n\nDo you want to start the compilation workflow?" 12 65 || exit 0

# Visual TTY1 Gauge Bar for Download initialization
(
  echo "10" ; sleep 0.3
  echo "XXX" ; echo "Preparing download environment..." ; echo "XXX"
  echo "40"
  echo "XXX" ; echo "Connecting to cdn.kernel.org..." ; echo "XXX"
) | dialog --title "Source Download" --gauge "Initializing..." 8 60 0

KERNEL_TARBALL="linux-${VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${VERSION%%.*}.x/${KERNEL_TARBALL}"
SRC_DIR="/usr/src/linux-${VERSION}"

cd /usr/src
if [ ! -d "$SRC_DIR" ]; then
    # Pipes download progress smoothly into dialog gauge
    wget -q --show-progress "$KERNEL_URL" 2>&1 | tr '\r' '\n' | awk '
    /^[0-9]+/ { print $1 }' | dialog --title "Downloading Kernel" --gauge "Fetching $KERNEL_TARBALL..." 8 60 0
    
    (
      echo "75" ; echo "XXX" ; echo "Extracting kernel sources to /usr/src..." ; echo "XXX"
      tar -xf "$KERNEL_TARBALL"
      echo "95" ; echo "XXX" ; echo "Cleaning cache archive..." ; echo "XXX"
      rm -f "$KERNEL_TARBALL"
      echo "100" ; echo "XXX" ; echo "Extraction complete." ; echo "XXX"
    ) | dialog --title "Source Extraction" --gauge "Extracting..." 8 60 0
fi

clear
cd "$SRC_DIR" || { echo "ERROR: Source directory does not exist!"; exit 1; }
echo "Cleaning source tree..."
make clean && make mrproper

# DYNAMIC CURRENT CONFIGURATION DETECTION FOR SLACKWARE 15.0 STABLE
CURRENT_RUNNING=$(uname -r)
FOUND_CFG=""
if [ -f "/boot/config-generic-${CURRENT_RUNNING}" ]; then
    FOUND_CFG="/boot/config-generic-${CURRENT_RUNNING}"
elif [ -f "/boot/config-huge-${CURRENT_RUNNING}" ]; then
    FOUND_CFG="/boot/config-huge-${CURRENT_RUNNING}"
else
    FOUND_CFG=$(ls -t /boot/config-generic-5.15.* 2>/dev/null | head -n 1)
    [[ -z "$FOUND_CFG" ]] && FOUND_CFG=$(ls -t /boot/config-[gh]* 2>/dev/null | head -n 1)
fi

if [ -n "$FOUND_CFG" ] && [ -f "$FOUND_CFG" ]; then
    echo "Copying official Slackware base configuration: $FOUND_CFG"
    cp "$FOUND_CFG" .config
else
    echo "ERROR: No base configuration file found in /boot!"
    exit 1
fi

echo "Running localmodconfig to reduce inactive modules..."
make localmodconfig

if [ "$PROFILE" == "2" ]; then
    echo "Applying Protected Desktop preset configurations..."
    sed -i 's/^CONFIG_PREEMPT_NONE=y/# CONFIG_PREEMPT_NONE is not set/' .config
    sed -i 's/^# CONFIG_PREEMPT_VOLUNTARY is not set/CONFIG_PREEMPT_VOLUNTARY=y/' .config
    sed -i 's/^CONFIG_PREEMPT_DYNAMIC=y/CONFIG_PREEMPT_DYNAMIC=n/' .config
    
    # BULLETPROOF PROTECTION: Force storage controllers and common filesystems to built-in (y)
    for key in CONFIG_USB CONFIG_USB_SUPPORT CONFIG_USB_XHCI_HCD CONFIG_USB_EHCI_HCD CONFIG_SCSI CONFIG_BLK_DEV_SD CONFIG_ATA CONFIG_SATA_AHCI CONFIG_BLK_DEV_NVME CONFIG_EXT4_FS CONFIG_EXFAT_FS CONFIG_NTFS3_FS CONFIG_FAT_FS CONFIG_VFAT_FS CONFIG_ISO9660_FS CONFIG_JOLIET CONFIG_UDF_FS CONFIG_BLK_DEV_SR CONFIG_NLS CONFIG_NLS_UTF8 CONFIG_NLS_ISO8859_1 CONFIG_NLS_ISO8859_2 CONFIG_NLS_ISO8859_15 CONFIG_NLS_CODEPAGE_437 CONFIG_NLS_CODEPAGE_850 CONFIG_NLS_CODEPAGE_852 CONFIG_NLS_CODEPAGE_866; do
        sed -i "s/^# ${key} is not set/${key}=y/" .config
        sed -i "s/${key}=m/${key}=y/" .config
        grep -q "^${key}=" .config || echo "${key}=y" >> .config
    done

    for key in CONFIG_USB_STORAGE CONFIG_USB_UAS CONFIG_CHR_DEV_SG CONFIG_HID CONFIG_HID_GENERIC CONFIG_USB_HID; do
        sed -i "s/^# ${key} is not set/${key}=m/" .config
        grep -q "^${key}=" .config || echo "${key}=m" >> .config
    done
fi

echo "Opening menuconfig. Verify Preemption Model -> Voluntary, then SAVE and EXIT."
sleep 2
make menuconfig

echo "Compiling kernel - output redirected to tty1 console stream..."
make -j"$CORES"

echo "Installing modules..."
make modules_install

echo "Copying final build binaries to /boot..."
cp arch/x86/boot/bzImage "/boot/vmlinuz-$VERSION"
cp System.map "/boot/System.map-$VERSION"
cp .config "/boot/config-$VERSION"

echo "Updating boot directory symlinks..."
cd /boot
ln -sf "vmlinuz-$VERSION" vmlinuz
ln -sf "System.map-$VERSION" System.map
ln -sf "config-$VERSION" config

echo "=== PROTECTED INITRD STAGE ==="
echo "Generating protected initrd image for $ROOT_DEV..."
mkinitrd -c -k "$VERSION" -f ext4 -r "$ROOT_DEV" -m ext4:ahci:nvme:xhci-hcd:ehci-hcd:usb-storage:uas:hid:hid-generic:usbhid -o "$INITRD_OUT"

echo "=== KERNEL BACKUP STAGE ==="
BACKUP_DIR="/boot/kernel-backups/$VERSION"
mkdir -p "$BACKUP_DIR"

cp -a "/boot/vmlinuz-$VERSION" "$BACKUP_DIR/"
cp -a "/boot/System.map-$VERSION" "$BACKUP_DIR/"
cp -a "/boot/config-$VERSION" "$BACKUP_DIR/"
cp -a "$INITRD_OUT" "$BACKUP_DIR/initrd-$VERSION.gz"

cat > "$BACKUP_DIR/REPAIR.txt" <<EOF
Slackware 15.0 - Kernel backup and repair instructions
=======================================================

Kernel version:
  $VERSION

Backup directory:
  /boot/kernel-backups/$VERSION

Files backed up:
  vmlinuz-$VERSION
  System.map-$VERSION
  config-$VERSION
  initrd-$VERSION.gz

IF THE NEW KERNEL DOES NOT BOOT
--------------------------------
1. Boot the previous working Slackware kernel from GRUB.
2. Become root.
3. Verify the backup:
     ls -lh /boot/kernel-backups/$VERSION/

4. Restore the kernel files if necessary:
     cp -a /boot/kernel-backups/$VERSION/vmlinuz-$VERSION /boot/
     cp -a /boot/kernel-backups/$VERSION/System.map-$VERSION /boot/
     cp -a /boot/kernel-backups/$VERSION/config-$VERSION /boot/

5. Restore the initrd:
     cp -a /boot/kernel-backups/$VERSION/initrd-$VERSION.gz /boot/
     ln -sfn initrd-$VERSION.gz /boot/initrd.gz

6. Regenerate GRUB:
     grub-mkconfig -o /boot/grub/grub.cfg

7. Reboot and select the restored kernel.

IMPORTANT:
- Do not delete the backup directory until the new kernel has been
  successfully tested.
- If the installed system does not boot, these same files can be restored
  from a LiveCD after mounting the Slackware root partition.
EOF

echo "Kernel backup created in: $BACKUP_DIR"

clear
select_bootloader

case "$BOOT_CHOICE" in
    1) grub-mkconfig -o /boot/grub/grub.cfg ;;
    2) eliloconfig ;;
    3) lilo ;;
esac

dialog --title "Workflow Complete" --yesno "Kernel build workflow finished successfully!\n\nDo you want to reboot the system now?" 10 60
response=$?
clear
if [ $response -eq 0 ]; then
    RUNLEVEL=$(dialog --title "Reboot Runlevel" --menu \
        "Choose the runlevel for the current session before reboot:" 10 70 2 \
        "3" "Init 3 - Text mode (recommended for NVIDIA driver work)" \
        "4" "Init 4 - Graphical mode" \
        3>&1 1>&2 2>&3) || exit 0

    clear

    case "$RUNLEVEL" in
        3)
            init 3
            reboot
            ;;
        4)
            init 4
            reboot
            ;;
        *)
            exit 0
            ;;
    esac
fi
exit 0

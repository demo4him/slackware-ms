#!/bin/sh
#
# rebuild-initrd-slack15.sh
# Slackware 15.0 Stable / huge kernel 5.15.209
#

KERNEL=5.15.209
ROOT=/dev/sda3
INITRD=/boot/initrd.gz

echo "Building initrd for kernel $KERNEL..."

if [ "`id -u`" != 0 ]; then
    echo "Run as root."
    exit 1
fi

if [ -f "$INITRD" ]; then
    cp -a "$INITRD" "$INITRD.before-cleanup"
fi

/sbin/mkinitrd -c \
  -k "$KERNEL" \
  -f ext4 \
  -r "$ROOT" \
  -m xhci-pci:ohci-pci:ehci-pci:xhci-hcd:uhci-hcd:ehci-hcd:hid:usbhid:i2c-hid:hid_generic:hid-asus:hid-cherry:hid-logitech:hid-logitech-dj:hid-logitech-hidpp:hid-lenovo:hid-microsoft:hid_multitouch \
  -u \
  -o "$INITRD"

if [ $? -eq 0 ]; then
    echo
    echo "INITRD rebuilt successfully."
    echo
    echo "Built-in filesystem modules intentionally omitted:"
    echo "  ext4"
    echo "  jbd2"
    echo "  mbcache"
    echo "  crc32c"
    echo
    ls -lh "$INITRD"
    exit 0
fi

echo "ERROR: mkinitrd failed."
exit 1

chmod +x rebuild-initrd-slack15.sh
sudo ./rebuild-initrd-slack15.sh
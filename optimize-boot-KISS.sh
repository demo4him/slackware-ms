#!/bin/sh
set -eu

# Slackware 15.0 Stable boot optimization.
# KISS: system parameters + GRUB kernel parameters only.
# Does not touch rc.d, SPEЕDER, slackboot-optimize, or initrd contents.

GRUB_DEFAULT=/etc/default/grub
SYSCTL_CONF=/etc/sysctl.conf

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Eroare: sudo nu este disponibil. Rulează scriptul ca root."
    exit 1
fi

command -v sysctl >/dev/null 2>&1 || {
    printf '%s\n' "Eroare: sysctl nu este disponibil."
    exit 1
}

command -v grub-mkconfig >/dev/null 2>&1 || {
    printf '%s\n' "Eroare: grub-mkconfig nu este disponibil."
    exit 1
}

if [ ! -f "$GRUB_DEFAULT" ]; then
    printf '%s\n' "Eroare: $GRUB_DEFAULT nu există."
    exit 1
fi

# Preserve the existing sysctl configuration. Add the requested values only
# when they are not already defined.
set_sysctl()
{
    key=$1
    value=$2

    if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$SYSCTL_CONF" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$SYSCTL_CONF"
    else
        printf '%s\n' "${key}=${value}" >> "$SYSCTL_CONF"
    fi
}

touch "$SYSCTL_CONF"
set_sysctl vm.swappiness 10
set_sysctl vm.vfs_cache_pressure 50

# Disable IPv6 only if these parameters are already part of the requested
# configuration; keep the original behavior from the supplied script.
set_sysctl net.ipv6.conf.all.disable_ipv6 1
set_sysctl net.ipv6.conf.default.disable_ipv6 1

sysctl -p "$SYSCTL_CONF" >/dev/null

# Update only the intended GRUB settings.
TMP="${GRUB_DEFAULT}.tmp.$$"

awk '
BEGIN { timeout_done=0; cmd_done=0 }
(/^GRUB_TIMEOUT=/) {
    print "GRUB_TIMEOUT=3"
    timeout_done=1
    next
}
(/^GRUB_CMDLINE_LINUX_DEFAULT=/) {
    line=$0
    sub(/^GRUB_CMDLINE_LINUX_DEFAULT="/, "", line)
    sub(/"$/, "", line)

    gsub(/(^|[[:space:]])initcall_debug([[:space:]]|$)/, " ", line)
    gsub(/[[:space:]]+/, " ", line)

    if (line !~ /(^|[[:space:]])quiet([[:space:]]|$)/)
        line = line " quiet"
    if (line !~ /(^|[[:space:]])loglevel=0([[:space:]]|$)/)
        line = line " loglevel=0"
    if (line !~ /(^|[[:space:]])splash([[:space:]]|$)/)
        line = line " splash"
    if (line !~ /(^|[[:space:]])fastboot([[:space:]]|$)/)
        line = line " fastboot"
    if (line !~ /(^|[[:space:]])libahci\.ignore_sss=1([[:space:]]|$)/)
        line = line " libahci.ignore_sss=1"
    if (line !~ /(^|[[:space:]])pata_legacy\.probe_mask=0([[:space:]]|$)/)
        line = line " pata_legacy.probe_mask=0"

    sub(/^ /, "", line)
    sub(/ $/, "", line)

    print "GRUB_CMDLINE_LINUX_DEFAULT=\"" line "\""
    cmd_done=1
    next
}
{ print }
END {
    if (!timeout_done)
        print "GRUB_TIMEOUT=3"
    if (!cmd_done)
        print "GRUB_CMDLINE_LINUX_DEFAULT=\"pata_legacy.probe_mask=0\""
}
' "$GRUB_DEFAULT" > "$TMP"

if [ ! -s "$TMP" ] ||
   ! grep -q '^GRUB_TIMEOUT=' "$TMP" ||
   ! grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$TMP"; then
    rm -f "$TMP"
    printf '%s\n' "Eroare: configurația GRUB nu a fost generată corect."
    exit 1
fi

cp -p "$GRUB_DEFAULT" "${GRUB_DEFAULT}.bak"
mv "$TMP" "$GRUB_DEFAULT"

grub-mkconfig -o /boot/grub/grub.cfg >/dev/null

printf '%s\n' "[OK] Slackware 15.0 boot configuration updated."
printf '%s\n' "[OK] GRUB_TIMEOUT=3"
printf '%s\n' "[OK] pata_legacy.probe_mask=0"
printf '%s\n' "[OK] Existing /etc/sysctl.conf entries were preserved."
printf '%s\n' "[OK] rc.d, SPEЕDER and initrd were not modified."

exit 0

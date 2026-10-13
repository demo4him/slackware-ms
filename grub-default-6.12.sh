#!/bin/bash
# Slackware 15.0 - Set Linux 6.12.112 as GRUB default
# Keep Linux 5.15.19 available as a fallback.

set -Eeuo pipefail

DEFAULT_TITLE="Slackware-15.0 GNU/Linux, with Linux 6.12.112"
GRUB_DEFAULT_FILE="/etc/default/grub"
GRUB_CONFIG="/boot/grub/grub.cfg"

if [ "$(id -u)" -ne 0 ]; then
    echo "Ruleaza scriptul ca root: su -"
    echo "Apoi: bash grub-default-6.12.sh"
    exit 1
fi

for cmd in grub-mkconfig cp grep sed date; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Eroare: comanda lipseste: $cmd"
        exit 1
    }
done

if [ ! -f "$GRUB_DEFAULT_FILE" ] ||
   [ ! -f "$GRUB_CONFIG" ]; then
    echo "Eroare: fisierele GRUB asteptate nu exista."
    echo "Nu am modificat nimic."
    exit 1
fi

if ! grep -Fq "$DEFAULT_TITLE" "$GRUB_CONFIG"; then
    echo "Eroare: intrarea Linux 6.12.112 nu a fost gasita."
    echo "Nu am modificat nimic."
    exit 1
fi

BACKUP="/root/grub-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
cp -a "$GRUB_DEFAULT_FILE" "$BACKUP/default-grub"
cp -a "$GRUB_CONFIG" "$BACKUP/grub.cfg"

restore_grub() {
    echo "Eroare! Restaurez configuratia anterioara..."
    cp -a "$BACKUP/default-grub" "$GRUB_DEFAULT_FILE"
    cp -a "$BACKUP/grub.cfg" "$GRUB_CONFIG"
}
trap restore_grub ERR

# Set the exact default menu entry.
sed -i '/^[[:space:]]*#*[[:space:]]*GRUB_DEFAULT=/d' \
    "$GRUB_DEFAULT_FILE"

printf '\nGRUB_DEFAULT="%s"\n' "$DEFAULT_TITLE" \
    >> "$GRUB_DEFAULT_FILE"

# Regenerate GRUB configuration.
grub-mkconfig -o "$GRUB_CONFIG"

# Verify that both kernels remain available.
if ! grep -Fq "$DEFAULT_TITLE" "$GRUB_CONFIG"; then
    echo "Eroare: intrarea implicita nu mai exista."
    false
fi

if ! grep -Fq "with Linux 5.15.19" "$GRUB_CONFIG"; then
    echo "Atentie: nu am gasit intrarea Linux 5.15.19."
    echo "Verifica meniul GRUB inainte de restart."
    false
fi

trap - ERR

echo
echo "Configurare terminata!"
echo "Implicit: Linux 6.12.112"
echo "Fallback: Linux 5.15.19"
echo "Backup: $BACKUP"
echo
echo "Recomandare: reporneste calculatorul si verifica meniul GRUB."
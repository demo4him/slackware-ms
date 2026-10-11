#!/bin/sh
set -e

REPO_URL="https://slackware.uk/slackware/slackware64-15.0/"
BACKTITLE="Slackware Updater"
MIRROR_FILE="/etc/slackpkg/mirrors"

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Eroare: sudo nu este disponibil. Rulează scriptul ca root."
    exit 1
fi

dialog --backtitle "$BACKTITLE" \
       --title "Slackware Updater" \
       --msgbox "Slackware Updater" 10 50

dialog --backtitle "$BACKTITLE" \
       --infobox "Configuring Slackware 15.0 mirror..." 8 50

printf '%s\n' "$REPO_URL" > "$MIRROR_FILE"

dialog --backtitle "$BACKTITLE" \
       --infobox "Updating package repository list...\nPlease wait." 8 45

slackpkg update

dialog --backtitle "$BACKTITLE" \
       --infobox "Upgrading all packages...\nThis may take some time." 8 50

slackpkg upgrade-all

boot_choice=$(dialog --backtitle "$BACKTITLE" \
    --title "Actualizare Bootloader" \
    --stdout \
    --menu "Alege bootloader-ul instalat pe sistemul tău pentru reconfigurare:" \
    13 60 3 \
    "1" "GRUB (grub-mkconfig)" \
    "2" "ELILO (eliloconfig)" \
    "3" "LILO (liloconfig & lilo)")

case "$boot_choice" in
    1)
        dialog --backtitle "$BACKTITLE" \
               --infobox "Running grub-mkconfig...\nUpdating GRUB boot configuration." 8 50
        grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    2)
        dialog --backtitle "$BACKTITLE" \
               --infobox "Running eliloconfig...\nCopying new kernel to EFI System Partition." 8 50
        eliloconfig
        ;;
    3)
        dialog --backtitle "$BACKTITLE" \
               --infobox "Running liloconfig & lilo...\nUpdating LILO boot configuration." 8 50
        liloconfig
        lilo
        ;;
    *)
        dialog --backtitle "$BACKTITLE" \
               --title "Atenție" \
               --msgbox "Nu a fost selectat niciun bootloader. Se trece peste acest pas." 8 50
        ;;
esac

dialog --backtitle "$BACKTITLE" \
       --title "Configurare Finalizată" \
       --msgbox "Slackware fully updated. Reboot your system." 10 50

exit 0

#!/bin/sh
set -eu

# Slackware 15.0 Stable cleanup.
# KISS: cleanup only. No rc.d permission changes, no bootloader changes,
# no rc.M/rc.S edits, no /etc/slackpkg/blacklist changes.

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -H "$0" "$@"
    fi
    printf '%s\n' "Eroare: sudo nu este disponibil. Rulează scriptul ca root."
    exit 1
fi

command -v dialog >/dev/null 2>&1 || {
    printf '%s\n' "Eroare: dialog nu este instalat."
    exit 1
}

dialog --title "Slackware 15.0 Cleanup" \
    --yesno "Pornești curățarea sistemului?\n\nVor fi eliminate doar pachetele și fișierele selectate.\n\nNu sunt modificate serviciile rc.d, boot-ul sau blacklist-ul slackpkg." \
    12 68 || exit 0

PKGS="iw b43-fwcutter broadcom-sta blueman bluetooth-firmware gtk4-demo ibus ibus-hangul scim fcitx5 fcitx5-chinese-addons fcitx5-gtk fcitx5-hangul fcitx5-anthy fcitx5-kkc fcitx5-m17n fcitx5-table-extra fcitx5-table-other fcitx5-lua opencc anthy-unicode fcitx5-qt fcitx5-configtool ibus-anthy ibus-kkc ibus-libpinyin ibus-m17n ibus-table wqy-zenhei-font-ttf sazanami-fonts-ttf sinhala-fonts-ttf lohit-fonts-ttf khmer-fonts-ttf tibetan-fonts-ttf sil-padauk-fonts-ttf font-jis-misc font-daewoo-misc font-cronyx-cyrillic font-mutt-misc xf86-video-voodoo xf86-video-savage xf86-video-neomagic xf86-video-trident xf86-video-sis xf86-video-mach64 xf86-video-r128 xf86-input-joystick xedit xclock xcalc xeyes xload xinput_calibrator mozilla-thunderbird seamonkey soma moc workbone sc jed joe biff+comsat finger talk talk-server popa3d lynx emacs pan pidgin hexchat zenmap xfig hplip gpa xine-ui telnet telnet-server ftp ftp-server compiz fvwm blackbox fluxbox windowmaker twm"

dialog --title "Cleanup Progress" --infobox \
    "Removing selected packages..." 8 50

# Remove the old "Y" package family, if present.
for pkg in /var/log/packages/*-x86_64-*_y* /var/log/packages/*-noarch-*_y*; do
    [ -f "$pkg" ] || continue
    removepkg "$(basename "$pkg")" >/dev/null 2>&1 || true
done

for pkg in $PKGS; do
    removepkg "$pkg" >/dev/null 2>&1 || true
done

# The original KDE command was missing removepkg and therefore did not
# actually remove anything. Remove only the explicitly named packages.
for pkg in calligra k3b koffice; do
    removepkg "$pkg" >/dev/null 2>&1 || true
done

# Keep the user's local applications intact; only hide selected desktop
# entries by creating NoDisplay overrides.
L_APP="/home/marius/.local/share/applications"
L_DIR="/home/marius/.local/share/desktop-directories"

if [ -d /home/marius ]; then
    mkdir -p "$L_APP" "$L_DIR"

    printf '%s\n' \
        '[Desktop Entry]' \
        'Version=1.0' \
        'Type=Directory' \
        'Icon=applications-development' \
        'NoDisplay=true' \
        > "$L_DIR/xfce-development.directory"

    printf '%s\n' \
        '[Desktop Entry]' \
        'Version=1.0' \
        'Type=Directory' \
        'Icon=applications-other' \
        'NoDisplay=true' \
        > "$L_DIR/xfce-other.directory"

    for file in /usr/share/applications/*.desktop; do
        [ -f "$file" ] || continue
        name=$(basename "$file")

        if grep -qE 'Categories=.*([Dd]evelopment|[Oo]ther)' "$file" 2>/dev/null ||
           grep -qE 'glade|gtk-demo|gtk3-demo|gtk4-demo|widget-factory|qtavplayer|qmlplayer|gdb|git-gui|kdevelop|assistant|designer|linguist|qdbusviewer|cmake-gui|qv4l2|qvidcap|gpa|KeepassXC|gcdmaster|vulkanCaps|distcc|xman|xterm|uxterm|xine|zenmap|avahi' "$file" 2>/dev/null ||
           ! grep -q '^Categories=' "$file" 2>/dev/null; then
            {
                printf '%s\n' '[Desktop Entry]'
                printf '%s\n' 'NoDisplay=true'
            } > "$L_APP/$name"
        fi
    done

    chown -R marius:users "$L_APP" "$L_DIR" 2>/dev/null || true

    # Hide the "Other" category from the Whisker Menu without installing a menu editor.
    # Xfce/Whisker reads this desktop-directory override from the user's menu data.
    printf '%s\n'         '[Desktop Entry]'         'Version=1.0'         'Type=Directory'         'Name=Other'         'NoDisplay=true'         > "$L_DIR/xfce-other.directory"
fi

# Remove selected non-English aspell dictionaries, keeping English.
for pkg in /var/log/packages/aspell-[a-z][a-z]*; do
    [ -f "$pkg" ] || continue
    case "$(basename "$pkg")" in
        aspell-en*) ;;
        *) removepkg "$(basename "$pkg")" >/dev/null 2>&1 || true ;;
    esac
done

# Remove translated man pages and unused locale directories.
find /usr/share/man -mindepth 1 -maxdepth 1 -type d \
    \( -name it -o -name fr -o -name de -o -name ja -o -name es \
       -o -name sv -o -name pl -o -name ru -o -name zh \) \
    -exec rm -rf {} + 2>/dev/null || true

find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
    ! -name ro ! -name ro_RO ! -name en ! -name en_US ! -name locale.alias \
    -exec rm -rf {} + 2>/dev/null || true

# Remove package/build caches only.
rm -rf /tmp/SBo/* /var/cache/sbopkg/* 2>/dev/null || true
find /var/cache/slackpkg -type f -name '*.txz' -delete 2>/dev/null || true

# Remove documentation files, as requested by the original cleanup.
find /usr/doc -mindepth 2 -type f -delete 2>/dev/null || true
find /usr/doc -mindepth 2 -type l -delete 2>/dev/null || true

# Clear old active logs, but do not touch wtmp: it is an accounting database.
for log in messages syslog debug secure; do
    [ -f "/var/log/$log" ] && : > "/var/log/$log"
done

fc-cache -f >/dev/null 2>&1 || true

dialog --title "Cleanup Complete" \
    --msgbox "Curățarea Slackware 15.0 s-a încheiat.\n\nServiciile rc.d și proiectele de boot nu au fost modificate." \
    10 60

exit 0

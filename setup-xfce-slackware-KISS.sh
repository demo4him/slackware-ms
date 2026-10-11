#!/bin/bash

# =====================================================================
# ANSI COLOR PALETTE CONFIGURATION
# =====================================================================
RC='\033[1;31m' GC='\033[1;32m' YC='\033[1;33m' BC='\033[1;34m' NC='\033[0m'

show_notification() {
    echo -e "\n${GC}*** $1 ***${NC}\n${BC}$2${NC}\n" && sleep 2
}

# 1. PRIVILEGE ESCALATION VERIFICATION (SUDO)
if [ "$EUID" -ne 0 ]; then
    echo -e "${YC}=== [Security] Script requires administrative privileges. ===${NC}"
    echo -e "${BC}=== Attempting to elevate via sudo... ===${NC}"
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    else
        echo -e "${RC}Error: 'sudo' is not configured. Please run manually as root.${NC}" && exit 1
    fi
fi

if ! command -v dialog >/dev/null 2>&1; then
    echo -e "${RC}Error: 'dialog' utility is not installed.${NC}" && exit 1
fi

# =====================================================================
# 2. NETWORK CONNECTIVITY CHECK
# =====================================================================
echo -e "${BC}=== [Network Check] Testing internet connection... ===${NC}"
ping -c 2 -W 3 slackware.uk >/dev/null 2>&1 || { echo -e "${RC}=== Error: Server slackware.uk is not responding! ===${NC}"; exit 1; }

# =====================================================================
# 3. GENUINE KISS METHOD FOR SBOPKG & SBOTOOLS (UPDATED URLS)
# =====================================================================
URL="https://github.com/sbopkg/sbopkg/releases/download/0.38.3/sbopkg-0.38.3-noarch-1_wsr.tgz"
FILENAME="sbopkg-0.38.3-noarch-1_wsr.tgz"

rm -f $FILENAME
echo -e "${BC}=== Downloading sbopkg via wget... ===${NC}"

# Running simple and clean wget, without output workarounds
wget $URL || { echo "Error: File could not be downloaded."; exit 1; }

echo "Installing package..."
installpkg $FILENAME || { echo "Error: Package could not be installed."; exit 1; }
rm -f $FILENAME

echo "Syncing with the repository..."
sbopkg -r || { echo "Error: Syncing with the repository failed."; exit 1; }

echo "Purging legacy package footprints..."
rm -rf /var/lib/pkgtools/packages/sbotools* /var/lib/pkgtools/scripts/sbotools*
rm -rf /usr/share/perl5/SBo /usr/share/perl5/SBO /usr/lib64/perl5/vendor_perl/SBO /usr/share/perl5/vendor_perl/SBO /usr/lib64/perl5/site_perl/SBO /usr/share/perl5/site_perl/SBO

echo "Installing sbotools..."
sbopkg -i sbotools || { echo "Error: sbotools could not be installed."; exit 1; }

echo "Configuring sbotools repository..."
sboconfig -r https://gitlab.com/SlackBuilds.org/slackbuilds.git

echo "Fetching latest snapshot with sbosnap..."
rm -rf /usr/sbo
sbosnap fetch || { echo "Error: Failed to fetch latest snapshot."; exit 1; }

# =====================================================================
# 4. OFFICIAL XFCE CACHE SYNCHRONIZATION
# =====================================================================
REPO_URL="rsync://slackware.uk/slackware/slackware64-15.0/slackware64/xfce/"
LOCAL_TARGET="/tmp/xfce-packages-15.0"
mkdir -p $LOCAL_TARGET

echo -e "${BC}Synchronizing XFCE system cache from slackware.uk...${NC}"
rsync -av --update --delete --exclude="*l10n*" $REPO_URL $LOCAL_TARGET/

cd $LOCAL_TARGET || exit 1
mapfile -t OFFICIAL_PACKAGES < <(ls *.txz 2>/dev/null)

# =====================================================================
# 5. INTERACTIVE DIALOG MENUS (ALL OPTIONS INITIALLY OFF)
# =====================================================================
OFFICIAL_TO_INSTALL=() && SBO_TO_INSTALL=()
TMP_XFCE=$(mktemp) && TMP_SBO=$(mktemp)

DIALOG_XFCE_ARGS=()
for pkg in "${OFFICIAL_PACKAGES[@]}"; do DIALOG_XFCE_ARGS+=("$pkg" "" "OFF"); done

dialog --backtitle "Slackware 15.0 XFCE Installer" --title " Official XFCE Packages Selection " --checklist "Use [SPACE] to toggle selection and [ENTER] to confirm:" 20 75 12 "${DIALOG_XFCE_ARGS[@]}" 2> $TMP_XFCE

eval chosen_xfce=($(cat $TMP_XFCE))
for pkg_clean in "${chosen_xfce[@]}"; do [ -n "$pkg_clean" ] && OFFICIAL_TO_INSTALL+=("$LOCAL_TARGET/$pkg_clean"); done

dialog --backtitle "Slackware 15.0 XFCE Installer" --title " SlackBuilds 15.0 Optional Selection " --checklist "Choose what you want to compile automatically:" 18 65 7 \
"xarchiver" "" "OFF" \
"thunar-archive-plugin" "" "OFF" \
"lightdm" "" "OFF" \
"lightdm-slick-greeter" "" "OFF" \
"lxdm" "" "OFF" \
"xfce4-genmon-plugin" "" "OFF" 2> $TMP_SBO
    "xfce4-xkb-plugin" "" "OFF"

eval chosen_sbo=($(cat $TMP_SBO))
for sbo_clean in "${chosen_sbo[@]}"; do [ -n "$sbo_clean" ] && SBO_TO_INSTALL+=("$sbo_clean"); done

rm -f $TMP_XFCE $TMP_SBO && clear

# =====================================================================
# 6. EXECUTION PHASE I: OFFICIAL PACKAGES
# =====================================================================
if [ ${#OFFICIAL_TO_INSTALL[@]} -gt 0 ]; then
    echo "Installing selected official XFCE packages..."
    upgradepkg --install-new "${OFFICIAL_TO_INSTALL[@]}"
fi

if [ -f /etc/X11/xinit/xinitrc.xfce ]; then
    rm -f /etc/X11/xinit/xinitrc && ln -s xinitrc.xfce /etc/X11/xinit/xinitrc
fi

# =====================================================================
# 7. EXECUTION PHASE II: AUTOMATED COMPILATION VIA SBOTOOLS
# =====================================================================
LIGHTDM_INSTALLED=0 && LXDM_INSTALLED=0

# Determine the desktop user dynamically.
# When launched through sudo, SUDO_USER identifies the real user.
if [ -n "${SUDO_USER:-}" ] && id "$SUDO_USER" >/dev/null 2>&1 && [ "$SUDO_USER" != "root" ]; then
    DESKTOP_USER="$SUDO_USER"
else
    DESKTOP_USER="${DESKTOP_USER:-${USER:-}}"
fi

if [ -z "$DESKTOP_USER" ] || ! id "$DESKTOP_USER" >/dev/null 2>&1 || [ "$DESKTOP_USER" = "root" ]; then
    echo "Error: could not determine a normal desktop user."
    exit 1
fi

# Desktop access permissions, based only on the supplied chmod_PERSONAL.sh.
DESKTOP_HOME="$(getent passwd "$DESKTOP_USER" | cut -d: -f6)"

if [ -n "$DESKTOP_HOME" ] && [ -d "$DESKTOP_HOME" ]; then
    chown -hR "$DESKTOP_USER:root" "$DESKTOP_HOME" 2>/dev/null || true
    chmod o+rw "$DESKTOP_HOME"/* 2>/dev/null || true
fi

# Detect the separate SSD partition by device, regardless of its mount-point name
# (/DATA, /PERSONAL, /OWN, etc.). Never apply these permissions to system mounts.
DATA_MOUNT="$(findmnt -n -o TARGET /dev/sdb1 2>/dev/null || true)"

case "$DATA_MOUNT" in
    ""|/|/boot|/usr|/home)
        ;;
    *)
        if [ -d "$DATA_MOUNT" ]; then
            chown -hR "$DESKTOP_USER:root" "$DATA_MOUNT" 2>/dev/null || true
            [ -d "$DATA_MOUNT/$DESKTOP_USER" ] &&                 chown -hR "$DESKTOP_USER:root" "$DATA_MOUNT/$DESKTOP_USER" 2>/dev/null || true
            chmod o+rw "$DATA_MOUNT"/* 2>/dev/null || true
            [ -d "$DATA_MOUNT/$DESKTOP_USER" ] &&                 chmod o+rw "$DATA_MOUNT/$DESKTOP_USER"/* 2>/dev/null || true
        fi
        ;;
esac

chmod o+rw /dev/bus/usb* 2>/dev/null || true
chmod o+rw /dev/video* 2>/dev/null || true

if [ ${#SBO_TO_INSTALL[@]} -gt 0 ]; then
    echo "Starting automated compilation via sboinstall..."
    for sbo_pkg in "${SBO_TO_INSTALL[@]}"; do
        if [ "$sbo_pkg" == "lightdm" ]; then
            grep -q "^lightdm:" /etc/group || groupadd -g 288 lightdm
            grep -q "^lightdm:" /etc/passwd || useradd -u 288 -g lightdm -d /var/lib/lightdm -s /bin/false -c "LightDM" lightdm
        fi
        
        sboinstall -r "$sbo_pkg"
        
        [ "$sbo_pkg" == "lightdm" ] && [ -x /usr/bin/lightdm ] && LIGHTDM_INSTALLED=1
        [ "$sbo_pkg" == "lxdm" ] && [ -x /usr/sbin/lxdm ] && LXDM_INSTALLED=1
    done
fi

# =====================================================================
# 8. POST-CONFIGURATION AUTOMATION FOR LIGHTDM
# =====================================================================
if [ "$LIGHTDM_INSTALLED" -eq 1 ]; then
    LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
    if [ -f "$LIGHTDM_CONF" ]; then
        sed -i 's|#sessions-directory=.*|sessions-directory=/usr/share/xsessions:/usr/share/wayland-sessions|g' "$LIGHTDM_CONF"
        sed -i 's/#greeter-session=.*/greeter-session=lightdm-slick-greeter/g' "$LIGHTDM_CONF"
        sed -i 's/^greeter-session=.*/greeter-session=lightdm-slick-greeter/g' "$LIGHTDM_CONF"
        sed -i '/\[Seat:\*\]/,$d' "$LIGHTDM_CONF" 2>/dev/null
        sed -i '/\[SeatDefaults\]/,$d' "$LIGHTDM_CONF"
        printf '\n[SeatDefaults]\nautologin-user=%s\nautologin-user-timeout=0\nautologin-session=xfce\n' "$DESKTOP_USER" >> "$LIGHTDM_CONF"
    fi
fi

# =====================================================================
# 9. POST-CONFIGURATION AUTOMATION FOR LXDM
# =====================================================================
if [ "$LXDM_INSTALLED" -eq 1 ]; then
    LXDM_CONF="/etc/lxdm/lxdm.conf"
    if [ -f "$LXDM_CONF" ]; then
        # KISS setting: LXDM autologin is always the user "marius".
        if grep -q '^[[:space:]]*autologin=' "$LXDM_CONF"; then
            sed -i 's|^[[:space:]]*autologin=.*|autologin=marius|' "$LXDM_CONF"
        elif grep -q '^[[:space:]]*#[[:space:]]*autologin=' "$LXDM_CONF"; then
            sed -i 's|^[[:space:]]*#[[:space:]]*autologin=.*|autologin=marius|' "$LXDM_CONF"
        else
            printf '%s\n' 'autologin=marius' >> "$LXDM_CONF"
        fi
    fi
fi

# ---------------------------------------------------------------------
# rc.4: LXDM is deliberately first, LightDM second.
# This block is managed only by this XFCE installer.
# ---------------------------------------------------------------------
if [ "$LXDM_INSTALLED" -eq 1 ] || [ "$LIGHTDM_INSTALLED" -eq 1 ]; then
    RC4_FILE="/etc/rc.d/rc.4"
    if [ -f "$RC4_FILE" ]; then
        RC4_MODE=`stat -c '%a' "$RC4_FILE" 2>/dev/null || echo 755`
        cp "$RC4_FILE" "$RC4_FILE.bak" 2>/dev/null || { echo "Error: could not back up $RC4_FILE"; exit 1; }

        # Remove existing installer-managed LXDM/LightDM blocks.
        sed -i '/^[[:space:]]*if \[ -x \/usr\/sbin\/lxdm \]; then$/,/^[[:space:]]*fi$/d' "$RC4_FILE"
        sed -i '/^[[:space:]]*if \[ -x \/usr\/bin\/lightdm \]; then$/,/^[[:space:]]*fi$/d' "$RC4_FILE"

        # Insert our preferred order immediately before Slackware's GDM section.
        if grep -q '^# Try to use GNOME.*gdm session manager' "$RC4_FILE"; then
            sed -i '/^# Try to use GNOME.*gdm session manager/i if [ -x /usr/sbin/lxdm ]; then\n  exec /usr/sbin/lxdm -nodaemon\nfi\n\nif [ -x /usr/bin/lightdm ]; then\n  exec /usr/bin/lightdm\nfi\n' "$RC4_FILE"
        else
            echo "Error: could not find safe rc.4 insertion point."
            cp "$RC4_FILE.bak" "$RC4_FILE"
            chmod "$RC4_MODE" "$RC4_FILE" 2>/dev/null || true
            exit 1
        fi

        chmod "$RC4_MODE" "$RC4_FILE" 2>/dev/null || chmod +x "$RC4_FILE"
        sh -n "$RC4_FILE" || {
            echo "Error: generated rc.4 is not valid shell."
            cp "$RC4_FILE.bak" "$RC4_FILE"
            chmod "$RC4_MODE" "$RC4_FILE" 2>/dev/null || true
            exit 1
        }
    fi
fi

if [ "$LIGHTDM_INSTALLED" -eq 1 ] || [ "$LXDM_INSTALLED" -eq 1 ]; then
    read -r -p "Enable automatic graphical launch at boot (Runlevel 4)? [Y/n]: " change_runlevel
    case "$change_runlevel" in [nN]*) ;; *) [ -f /etc/inittab ] && sed -i 's/id:3:initdefault:/id:4:initdefault:/g' /etc/inittab ;; esac
fi

# =====================================================================
# 10. XFCONF-QUERY SESSION OPTIONS
# =====================================================================
# The installer must finish cleanly from tty1.  xfconf-query requires the
# user's real XFCE/D-Bus session, so it is deliberately NOT executed here.
# A one-shot XFCE autostart helper applies the settings on first login.
# =====================================================================
DESKTOP_USER=marius
DESKTOP_HOME="/home/$DESKTOP_USER"
SESSION_HELPER="$DESKTOP_HOME/.local/bin/setup-xfce-session-once"
SESSION_AUTOSTART="$DESKTOP_HOME/.config/autostart/setup-xfce-session-once.desktop"

if id "$DESKTOP_USER" >/dev/null 2>&1 && [ -d "$DESKTOP_HOME" ]; then
    mkdir -p "$DESKTOP_HOME/.local/bin" "$DESKTOP_HOME/.config/autostart"

    cat > "$SESSION_HELPER" << 'SESSION_EOF'
#!/bin/sh

xfconf-query -c xfce4-session -np /shutdown/ShowHybridSleep -t bool -s false
xfconf-query -c xfce4-session -np /shutdown/ShowSuspend -t bool -s false
xfconf-query -c xfce4-session -np /shutdown/ShowSwitchUser -t bool -s false
xfconf-query -c xfce4-session -np /shutdown/ShowHibernate -t bool -s false

rm -f "$HOME/.config/autostart/setup-xfce-session-once.desktop"
rm -f "$HOME/.local/bin/setup-xfce-session-once"
exit 0
SESSION_EOF
    chmod +x "$SESSION_HELPER"

    cat > "$SESSION_AUTOSTART" << 'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=XFCE first-session setup
Comment=Apply initial XFCE session settings once
Exec=/home/marius/.local/bin/setup-xfce-session-once
Terminal=false
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
DESKTOP_EOF

    chown -R "$DESKTOP_USER:$DESKTOP_USER" "$DESKTOP_HOME/.local" "$DESKTOP_HOME/.config/autostart" 2>/dev/null || true
    echo "XFCE session settings will be applied on first login as $DESKTOP_USER."
else
    echo "User $DESKTOP_USER does not exist yet; skipping XFCE session helper."
fi

cd / || exit 1
show_notification "Mission Accomplished" "XFCE installation and TTY configuration completed successfully!"


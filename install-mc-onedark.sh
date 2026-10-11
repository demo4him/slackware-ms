#!/bin/sh

# ==============================================================================
# AUTOMATED MIDNIGHT COMMANDER ONE DARK SKIN REPLICATION SCRIPT (KISS STYLE)
# Author: Marius & AI | Environment: Pure Bash / POSIX-like / BSD style (No Systemd)
# Esthetics: ANSI Color Enhanced - Dual User/Root Activation & True Color
# ==============================================================================

set -e

# Standard ANSI Colors (POSIX-safe)
CLR_RESET="\033[0m"
CLR_INFO="\033[1;34m"    # Bold Blue
CLR_SUCCESS="\033[1;32m" # Bold Green
CLR_WARN="\033[1;33m"    # Bold Yellow
CLR_TEXT="\033[0;36m"    # Cyan
CLR_ERROR="\033[1;31m"   # Bold Red

print_step() {
    printf "${1}%s${CLR_RESET}\n" "$2"
    logger -t mc_onedark_kiss -p "user.${3}" "$2"
}

print_step "$CLR_INFO" "[i] --- LAUNCHING MC ONE DARK AUTOMATED REPLICATION (USER & ROOT) ---" "info"

# Determinăm automat utilizatorul curent non-root și directorul lui HOME
CURRENT_USER=$(logname 2>/dev/null || echo "$USER")
USER_HOME=$(eval echo "~$CURRENT_USER")

# Definire căi de lucru pentru Utilizatorul Curent
WORKSPACE_DIR="$USER_HOME/mc-onedark-theme"
USER_SKINS_DIR="$USER_HOME/.local/share/mc/skins"
USER_CONFIG_DIR="$USER_HOME/.config/mc"
SKIN_SOURCE="$USER_SKINS_DIR/onedark16M.ini"

# Definire căi de lucru pentru contul de ROOT
ROOT_SKINS_DIR="/root/.local/share/mc/skins"
ROOT_CONFIG_DIR="/root/.config/mc"
SKIN_TARGET_ROOT="$ROOT_SKINS_DIR/onedark16M.ini"

# ==============================================================================
# PASUL 1 & 2: CREARE DIRECTIOR WORKSPACE ȘI DESCĂRCARE REPO DE PE GITHUB
# ==============================================================================
print_step "$CLR_INFO" "[>] Preparing workspace and cloning repository from GitHub..." "info"
rm -rf "$WORKSPACE_DIR" # Curățare în caz de rulare anterioară eșuată
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

if command -v git >/dev/null 2>&1; then
    # Clonăm direct în folderul specificat explicit 'mc-onedark' conform cerințelor tale
    git clone https://github.com/DeadNews/mc-onedark.git mc-onedark
else
    print_step "$CLR_WARN" "[!] Git nu este instalat. Se încearcă descărcarea via wget..." "warning"
    wget -qO- https://github.com | tar xz
    mv mc-onedark-main mc-onedark
fi

# ==============================================================================
# PASUL 3 & 4: CREARE DIRECTOARE LOCALE UTILIZATOR ȘI REALIZARE SYMLINK
# ==============================================================================
print_step "$CLR_INFO" "[>] Setting up user local skins and creating symbolic link..." "info"
mkdir -p "$USER_SKINS_DIR"
cd "$USER_SKINS_DIR"

# Ștergem linkul vechi dacă exista deja, pentru a preveni erorile de re-linkare
rm -f onedark16M.ini
ln -s "$WORKSPACE_DIR/mc-onedark/skins/onedark16M.ini" onedark16M.ini

# Verificăm dacă fișierul este valid după legarea simbolică
if [ ! -f "$SKIN_SOURCE" ]; then
    print_step "$CLR_ERROR" "[!] Error: Symlink creation failed or target asset not found at: $SKIN_SOURCE" "err"
    exit 1
fi
print_step "$CLR_TEXT" "  → Symlink active under user profile: $SKIN_SOURCE" "info"

# ==============================================================================
# FAZA DE CONFIGURARE I: ACTIVARE ȘI TRUE COLOR PENTRU UTILIZATORUL LOCAL
# ==============================================================================
print_step "$CLR_INFO" "[>] Injecting 24-bit True Color variables into user shells..." "info"
if [ -f "$USER_HOME/.bashrc" ] && ! grep -q "COLORTERM=" "$USER_HOME/.bashrc"; then
    printf "\nexport COLORTERM=truecolor\n" >> "$USER_HOME/.bashrc"
fi
if [ -f "$USER_HOME/.profile" ] && ! grep -q "COLORTERM=" "$USER_HOME/.profile"; then
    printf "\nexport COLORTERM=truecolor\n" >> "$USER_HOME/.profile"
fi

print_step "$CLR_INFO" "[>] Activating theme inside user Midnight Commander configurations..." "info"
mkdir -p "$USER_CONFIG_DIR"
if [ -f "$USER_CONFIG_DIR/ini" ]; then
    sed -i "s|^skin=.*|skin=onedark16M|" "$USER_CONFIG_DIR/ini" 2>/dev/null || true
    if ! grep -q "^skin=" "$USER_CONFIG_DIR/ini"; then
        sed -i "/\[Options\]/a skin=onedark16M" "$USER_CONFIG_DIR/ini"
    fi
else
    printf "[Options]\nskin=onedark16M\n" > "$USER_CONFIG_DIR/ini"
fi
print_step "$CLR_TEXT" "  → Theme successfully activated for local user: $CURRENT_USER" "info"

# ==============================================================================
# FAZA DE CONFIGURARE II: REPLICARE ȘI ACTIVARE PENTRU CONTUL DE ROOT
# ==============================================================================
print_step "$CLR_INFO" "[>] Creating skin directories for ROOT profile and cloning file..." "info"
sudo mkdir -p "$ROOT_SKINS_DIR"
sudo cp -f "$SKIN_SOURCE" "$SKIN_TARGET_ROOT"
sudo chmod 644 "$SKIN_TARGET_ROOT"
print_step "$CLR_TEXT" "  → The onedark16M.ini file has been successfully cloned into the ROOT profile." "info"

# Forțare mod 24-bit True Color pentru shell-urile de root
print_step "$CLR_WARN" "[*] Appending 24-bit True Color runtime graphics variables inside root environment..." "notice"
sudo sh -c '
if [ -f /root/.bashrc ] && ! grep -q "COLORTERM=" /root/.bashrc; then
    printf "\nexport COLORTERM=truecolor\n" >> /root/.bashrc
fi
if [ -f /root/.profile ] && ! grep -q "COLORTERM=" /root/.profile; then
    printf "\nexport COLORTERM=truecolor\n" >> /root/.profile
fi
'

# Activare temă în fișierele de configurare root ale Midnight Commander
print_step "$CLR_INFO" "[>] Forcing explicit theme activation variables to onedark16M inside root configurations..." "info"
sudo mkdir -p "$ROOT_CONFIG_DIR"
sudo sh -c '
if [ -f /root/.config/mc/ini ]; then
    sed -i "s|^skin=.*|skin=onedark16M|" /root/.config/mc/ini 2>/dev/null || true
    if ! grep -q "^skin=" /root/.config/mc/ini; then
        sed -i "/\[Options\]/a skin=onedark16M" /root/.config/mc/ini
    fi
else
    printf "[Options]\nskin=onedark16M\n" > /root/.config/mc/ini
fi
'
print_step "$CLR_TEXT" "  → Configuration profiles for Midnight Commander written to root namespace files." "info"

print_step "$CLR_SUCCESS" "" "info"
print_step "$CLR_SUCCESS" "[✓] KISS AUTOMATION EXECUTED SUCCESSFULLY!" "info"
print_step "$CLR_SUCCESS" "[✓] Theme is now active for BOTH your normal user and root." "info"
print_step "$CLR_SUCCESS" "[✓] Execution engine terminating script in 4 seconds..." "info"

sleep 4

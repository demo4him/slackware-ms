#!/bin/bash
# ==============================================================================
# Automated Script for Installing MS Office 2007 on Slackware 15.0
# Created: Marius (Master Monolith Edition)
# ==============================================================================
set -e

# Run as the logged-in desktop user; sudo is used only for system-wide changes.
if [ "$(id -u)" -eq 0 ]; then
    echo "Run this installer as your normal XFCE user, not as root."
    exit 1
fi

CURRENT_USER="$(id -un)"
USER_HOME="$HOME"

# 1. Secured Global Environment Variables (Winetricks Fix & User Paths)
export CURRENT_USER
export WINEPREFIX="$USER_HOME/.winecx-office2007"
export WINE="/opt/winecx/bin/wine"
export WINESERVER="/opt/winecx/bin/wineserver"
export WINELOADER="/opt/winecx/bin/wine"
export WINEDLLPATH="/opt/winecx/lib/wine"
export PATH="/opt/winecx/bin:$PATH"

ISO_FILE="$USER_HOME/Downloads/Office2007.ISO"
PROOF_ZIP_URL="https://github.com/demo4him/slackware-ms/raw/refs/heads/main/Office2007-Proofing.zip"
MUI_ZIP_URL="https://sourceforge.net/projects/slackware-ms/files/Office2007-MUI-en-us.zip/download"
MUI_SHA256="44d9925f7ec8f175f4b286627d2f557fd0f56efe2b7ca22300974473c8998af2"
MOUNT_DIR="/tmp/office2007_mount"
EXTRACT_DIR="$USER_HOME/Downloads/Office2007"
REQ_ZIP="$USER_HOME/Downloads/Requests Office 2007.zip"

# Clear the terminal before opening the first dialog.
# Avoid reading from stdin here: it can consume pending keyboard input.
clear

# 1. Welcome and Wine verification in ONE dialog, so OK is pressed only once.
WINE_VERSION=$($WINE --version 2>&1 || echo "ERROR")
dialog --title "MS Office 2007 Installation" \
       --msgbox "\nWelcome, Friend!\n\nThis script will install Office 2007 on Slackware using an isolated 32-bit prefix.\n\nPrefix: $WINEPREFIX\n\nDetected Wine Version:\n$WINE_VERSION\n\nIf no error is reported, the Wine environment is ready." 15 70

# 3. System Dependencies Auditing (Smart & Native)
DEP_MISSING=0
if ! ls /var/log/packages/winetricks-* >/dev/null 2>&1 || \
   ! ls /var/log/packages/cabextract-* >/dev/null 2>&1 || \
   ! ls /var/log/packages/webcore-fonts-* >/dev/null 2>&1; then
    DEP_MISSING=1
fi

if [ $DEP_MISSING -eq 1 ]; then
    dialog --title "SlackBuilds Dependencies" \
           --yesno "Missing system dependencies detected. Do you want to trigger their installation via sboinstall?" 7 60

    if [ $? -eq 0 ]; then
        clear
        echo "Synchronizing sbopkg repositories..."
        sudo sbopkg -r
        echo "Installing required packages..."
        sudo sboinstall winetricks cabextract webcore-fonts samsung-mfp-drivers JetBrainsMono
    fi
else
    dialog --title "Dependencies Verified" \
           --infobox "All required packages (winetricks, cabextract, webcore-fonts) are already in the system!\nSkipping straight to prefix initialization..." 5 65
    sleep 2
fi

# 4. Prefix Generation and Initial Configuration setup mapping
dialog --title "Wine Prefix Setup" --infobox "Generating win32 prefix asset structures (wineboot)...\nPlease wait." 5 55
WINEARCH=win32 wineboot
sleep 2

dialog --title "OS Version Alignment" --infobox "Setting base prefix compatibility target layer to Windows 7..." 5 55
$WINE winecfg -v win7
sleep 2

# 5. Installing Runtime Component Blocks via Winetricks
dialog --title "Winetricks DLLs" \
       --msgbox "The script will now install the planned runtime libraries:\n- corefonts, msxml3\n- riched20, riched30\n- gdiplus, vcrun2005sp1\n\nThe process downloads external files and may take a few minutes." 11 60
clear
winetricks -q corefonts msxml3 riched20 riched30 gdiplus vcrun2005sp1

# Re-secure Windows 7 mode constraints following winetricks operations
$WINE winecfg -v win7

# 6. ISO Unpacking and Main Setup Execution Engine
if [ -f "$ISO_FILE" ]; then
    dialog --title "Processing Office ISO" --infobox "Mounting the loop ISO image and extracting installer assets to Downloads..." 5 60
    
    sudo mkdir -p "$EXTRACT_DIR"
    mkdir -p "$MOUNT_DIR"
    
    sudo mount -o loop "$ISO_FILE" "$MOUNT_DIR"
    sudo cp -R "$MOUNT_DIR"/* "$EXTRACT_DIR/"
    sudo umount "$MOUNT_DIR"
    
    dialog --title "Launching Office Installer" \
           --msgbox "Launching the Microsoft Office 2007 graphical wizard engine.\n\nEnter your license key in the pop-up window and complete the installation.\nThe script will wait for the setup process to terminate." 10 65
    clear
    
    $WINE "$EXTRACT_DIR/setup.exe"
    echo "Waiting for background Wine transaction server threads to settle..."
    wineserver -w
    
    sudo rm -rf "$EXTRACT_DIR"
else
    dialog --title "Critical Error" --msgbox "The target Office ISO image could not be verified at:\n$ISO_FILE\nMain installation sequence bypassed!" 7 60
fi

# 6A. Download and install Romanian + English Proofing Tools from GitHub
PROOF_TMP="$(mktemp -d "/tmp/office2007-proofing.XXXXXX")"
PROOF_ZIP="$PROOF_TMP/Office2007-Proofing.zip"
PROOF_ROOT="$PROOF_TMP/Office2007-Proofing"
PROOF_LOG_DIR="$HOME/Office2007-Proofing-Logs"

if dialog --title "Office 2007 Proofing Tools" \
          --yesno "Download the Romanian and English Proofing package from GitHub now?\n\nSource:\n$PROOF_ZIP_URL\n\nThe package will be verified and installed into the current WineCX prefix." 12 72; then
    dialog --title "GitHub Download" --infobox "Downloading Office 2007 Proofing Tools from GitHub...\nPlease wait." 6 65

    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --connect-timeout 20 "$PROOF_ZIP_URL" -o "$PROOF_ZIP"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$PROOF_ZIP" "$PROOF_ZIP_URL"
    else
        dialog --title "Download Error" --msgbox "Neither curl nor wget is available. Install one of them and run the installer again." 8 65
        rm -rf "$PROOF_TMP"
        exit 1
    fi

    dialog --title "Extracting Proofing Package" --infobox "Extracting the downloaded package..." 5 60
    if ! command -v unzip >/dev/null 2>&1 || ! unzip -q "$PROOF_ZIP" -d "$PROOF_TMP"; then
        dialog --title "Package Error" --msgbox "The GitHub Proofing ZIP could not be extracted." 7 60
        rm -rf "$PROOF_TMP"
        exit 1
    fi

    if [ ! -f "$PROOF_ROOT/SHA256SUMS" ]; then
        dialog --title "Package Error" --msgbox "The SHA256SUMS manifest is missing from the downloaded package." 7 65
        rm -rf "$PROOF_TMP"
        exit 1
    fi

    cd "$PROOF_ROOT"
    if ! sha256sum -c SHA256SUMS; then
        dialog --title "Integrity Check Failed" --msgbox "The Proofing package failed SHA256 verification. Installation has been cancelled." 8 70
        rm -rf "$PROOF_TMP"
        exit 1
    fi

    mkdir -p "$PROOF_LOG_DIR"

    install_proofing_language() {
        local language="$1"
        local msi="$PROOF_ROOT/Proof.$language/Proof.msi"
        local log="$PROOF_LOG_DIR/install-proof-$language.log"

        if [ ! -f "$msi" ]; then
            dialog --title "Proofing Package Error" --msgbox "Missing MSI installer for language: $language" 7 60
            return 1
        fi

        dialog --title "Installing Proofing Tools" --infobox "Installing language: $language\nPlease wait for the Microsoft Installer to finish." 6 60
        if "$WINE" msiexec /i "$msi" /L*v "$log"; then
            echo "Proofing installation completed: $language"
        else
            local status=$?
            if [ "$status" -eq 194 ]; then
                echo "Proofing installation requested a reboot: $language"
            else
                dialog --title "Proofing Installation Error" --msgbox "The $language installer returned exit code $status.\n\nLog file:\n$log" 9 70
                return "$status"
            fi
        fi
        "$WINESERVER" -w
    }

    if ! install_proofing_language ro || ! install_proofing_language en; then
        dialog --title "Proofing Installation Incomplete" --msgbox "The Romanian and English Proofing installation did not complete successfully. Check the logs in:\n$PROOF_LOG_DIR" 9 70
        rm -rf "$PROOF_TMP"
        exit 1
    fi

    dialog --title "Proofing Installation" --msgbox "Romanian and English Proofing Tools installation has completed.\n\nInstallation logs:\n$PROOF_LOG_DIR" 9 70
else
    dialog --title "Proofing Installation Skipped" --msgbox "The GitHub Proofing download was skipped. Office 2007 installation will continue without the optional proofing components." 8 70
fi

rm -rf "$PROOF_TMP"

# 6B. Download and install the English Office 2007 MUI
MUI_TMP="$(mktemp -d "/tmp/office2007-mui.XXXXXX")"
MUI_ZIP="$MUI_TMP/Office2007-MUI-en-us.zip"
MUI_ROOT="$MUI_TMP/Office2007-MUI-en-us"
MUI_LOG_DIR="$USER_HOME/Office2007-MUI-Logs"
mkdir -p "$MUI_LOG_DIR"

dialog --title "Office 2007 English Interface" \
       --msgbox "The script will download and install the English interface components for Word, Excel, PowerPoint and OneNote.\n\nThe existing Romanian and English Proofing Tools are installed separately and will be preserved." 11 72

dialog --title "Downloading English MUI" --infobox "Downloading Office 2007 English MUI from SourceForge...\nPlease wait." 6 65

if command -v curl >/dev/null 2>&1; then
    if ! curl -fL --retry 3 --connect-timeout 20 "$MUI_ZIP_URL" -o "$MUI_ZIP"; then
        dialog --title "MUI Download Error" --msgbox "The English MUI package could not be downloaded." 7 65
        rm -rf "$MUI_TMP"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -O "$MUI_ZIP" "$MUI_ZIP_URL"; then
        dialog --title "MUI Download Error" --msgbox "The English MUI package could not be downloaded." 7 65
        rm -rf "$MUI_TMP"
        exit 1
    fi
else
    dialog --title "Download Error" --msgbox "Neither curl nor wget is available. Install one of them and run the installer again." 8 65
    rm -rf "$MUI_TMP"
    exit 1
fi

dialog --title "Verifying English MUI" --infobox "Checking the SHA256 integrity of the downloaded package..." 5 65
if ! echo "$MUI_SHA256  $MUI_ZIP" | sha256sum -c -; then
    dialog --title "MUI Integrity Check Failed" --msgbox "The English MUI package failed SHA256 verification. Installation has been cancelled." 8 70
    rm -rf "$MUI_TMP"
    exit 1
fi

dialog --title "Extracting English MUI" --infobox "Extracting the verified English interface package..." 5 65
if ! command -v unzip >/dev/null 2>&1 || ! unzip -q "$MUI_ZIP" -d "$MUI_TMP"; then
    dialog --title "MUI Package Error" --msgbox "The English MUI ZIP could not be extracted." 7 65
    rm -rf "$MUI_TMP"
    exit 1
fi

# Install the individual MSI packages directly. The archive's setup.exe
# cannot identify an applicable Office product under WineCX.
MUI_REQUIRED_FILES=(
    "Word.en-us/WordMUI.msi"
    "Office.en-us/OfficeMUI.msi"
    "Office.en-us/OfficeMUISet.msi"
    "Excel.en-us/ExcelMUI.msi"
    "PowerPoint.en-us/PowerPointMUI.msi"
    "OneNote.en-us/OneNoteMUI.msi"
)

for relative_msi in "${MUI_REQUIRED_FILES[@]}"; do
    if [ ! -f "$MUI_ROOT/$relative_msi" ]; then
        dialog --title "MUI Package Error" \
               --msgbox "A required English MUI component is missing:\n$relative_msi\n\nInstallation has been cancelled." 9 70
        rm -rf "$MUI_TMP"
        exit 1
    fi
done

install_mui_component() {
    local relative_msi="$1"
    local component_name="$2"
    local msi="$MUI_ROOT/$relative_msi"
    local log="$MUI_LOG_DIR/${component_name}.log"

    dialog --title "Installing English MUI" \
           --infobox "Installing $component_name...\nPlease wait." 6 60

    if "$WINE" msiexec /i "$msi" \
        LAUNCHEDBYSETUPEXE=1 \
        INSTALLLOCATION="C:\\Program Files\\Microsoft Office" \
        /L*v "$log"; then
        echo "Installed: $component_name"
    else
        local status=$?
        if [ "$status" -eq 194 ]; then
            echo "Installer requested a reboot: $component_name"
        else
            dialog --title "MUI Installation Error" \
                   --msgbox "$component_name returned exit code $status.\n\nLog file:\n$log" 9 72
            return "$status"
        fi
    fi

    "$WINESERVER" -w
}

clear
# This sequence was verified with the existing Office 2007 WineCX prefix.
if ! install_mui_component "Word.en-us/WordMUI.msi" "Word-MUI" ||
   ! install_mui_component "Office.en-us/OfficeMUI.msi" "Office-Shared-MUI" ||
   ! install_mui_component "Office.en-us/OfficeMUISet.msi" "Office-MUI-Setup-Metadata" ||
   ! install_mui_component "Excel.en-us/ExcelMUI.msi" "Excel-MUI" ||
   ! install_mui_component "PowerPoint.en-us/PowerPointMUI.msi" "PowerPoint-MUI" ||
   ! install_mui_component "OneNote.en-us/OneNoteMUI.msi" "OneNote-MUI"; then
    dialog --title "MUI Installation Incomplete" \
           --msgbox "One or more English MUI components did not install successfully.\n\nCheck the logs in:\n$MUI_LOG_DIR" 9 72
    rm -rf "$MUI_TMP"
    exit 1
fi

rm -rf "$MUI_TMP"

dialog --title "English Interface Components Installed" \
       --msgbox "The English MUI components for Word, Excel, PowerPoint and OneNote have been installed.\n\nTo switch the interface, open:\nOffice 2007 -> Language Settings\n\nOn the Display Language tab, select English (U.S.) for menus, dialogs and Help, then restart all Office applications.\n\nRomanian and English Proofing Tools remain separate and are preserved." 13 74

# 7. PDF Add-in Implementation and System Icons Integration
if [ -f "$REQ_ZIP" ]; then
    dialog --title "Installing Add-ins" --infobox "Extracting files from Requests Office 2007.zip..." 5 60
    cd "$USER_HOME/Downloads"
    unzip -o "$REQ_ZIP"
    cd "Requests Office 2007"
    
    dialog --title "PDF Plugin" --msgbox "Launching the SaveAsPDFandXPS.exe add-in installer engine." 6 55
    clear
    $WINE SaveAsPDFandXPS.exe
    wineserver -w
    
    dialog --title "Icon Integration" --infobox "Unpacking branding visual assets and committing them to root storage grids..." 5 60
    unzip -o "Office 2007 icons.zip"
    ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
    sudo mkdir -p "$ICON_DIR"
    sudo cp "Office 2007 icons/"*.png "$ICON_DIR"/

    # The archive contains onenote2007.png alongside the other Office icons.
    # Install it directly; no separate download or filename search is needed.
    if [ -f "Office 2007 icons/onenote2007.png" ]; then
        sudo install -m 644 "Office 2007 icons/onenote2007.png" "$ICON_DIR/onenote2007.png"
    else
        echo "WARNING: onenote2007.png was not found in Office 2007 icons.zip."
    fi

    sudo gtk-update-icon-cache -f -q /usr/share/icons/hicolor/
else
    dialog --title "Warning" --msgbox "The requests supplementary archive package was not found. Skipping to launchers step." 6 60
fi

# 8. Wrappers Creation and Desktop Integration
dialog --title "Wrappers & Desktop Menu" --infobox "Generating global executable wrappers inside /opt and populating .desktop structures in the system menu..." 5 60

sudo mkdir -p /opt/winecx/launchers
sudo chmod 755 /opt/winecx/launchers

# Core wrapper authoring engine loop logic (secured permissions)
creaza_wrapper() {
    local nume_fisier=$1
    local cale_exe=$2
    sudo tee /opt/winecx/launchers/$nume_fisier > /dev/null <<WEOF
#!/bin/bash
set -e
export PATH="/opt/winecx/bin:\$PATH"
export WINEPREFIX="$USER_HOME/.winecx-office2007"
export WINESERVER="/opt/winecx/bin/wineserver"
export WINELOADER="/opt/winecx/bin/wine"
export LANG=C.UTF-8
export WINEDEBUG=-all
app="$cale_exe"
/opt/winecx/bin/wineserver -p >/dev/null 2>&1 || true
if [ \$# -eq 0 ]; then
    exec /opt/winecx/bin/wine "\$app"
else
    for file in "\$@"; do
        fullpath=\$(realpath "\$file")
        winpath="Z:\${fullpath//\//\\\\}"
        /opt/winecx/bin/wine "\$app" "\$winpath"
    done
fi
WEOF
    sudo chmod +x /opt/winecx/launchers/$nume_fisier
}

creaza_wrapper "word2007.sh" "C:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE"
creaza_wrapper "excel2007.sh" "C:\\Program Files\\Microsoft Office\\Office12\\EXCEL.EXE"
creaza_wrapper "powerpoint2007.sh" "C:\\Program Files\\Microsoft Office\\Office12\\POWERPNT.EXE"
creaza_wrapper "onenote2007.sh" "C:\\Program Files\\Microsoft Office\\Office12\\ONENOTE.EXE"
creaza_wrapper "office2007-language-settings.sh" "C:\\Program Files\\Microsoft Office\\Office12\\SETLANG.EXE"

# Writing out the unified .desktop system registry files
sudo tee /usr/share/applications/word2007.desktop > /dev/null <<'WEOF'
[Desktop Entry]
Name=Microsoft Word 2007
Comment=Microsoft Office 2007 word processor
Exec=/opt/winecx/launchers/word2007.sh %F
Type=Application
StartupNotify=true
Terminal=false
Icon=word2007
Categories=Office;WordProcessor;
MimeType=application/msword;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.ms-word.document.macroEnabled.12;application/rtf;text/plain;
WEOF

sudo tee /usr/share/applications/excel2007.desktop > /dev/null <<'WEOF'
[Desktop Entry]
Name=Microsoft Excel 2007
Comment=Microsoft Office 2007 spreadsheet
Exec=/opt/winecx/launchers/excel2007.sh %F
Type=Application
StartupNotify=true
Terminal=false
Icon=excel2007
Categories=Office;Spreadsheet;
MimeType=application/vnd.ms-excel;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;application/vnd.ms-excel.sheet.macroEnabled.12;text/csv;
WEOF

sudo tee /usr/share/applications/powerpoint2007.desktop > /dev/null <<'WEOF'
[Desktop Entry]
Name=Microsoft PowerPoint 2007
Comment=Microsoft Office 2007 presentation software
Exec=/opt/winecx/launchers/powerpoint2007.sh %F
Type=Application
StartupNotify=true
Terminal=false
Icon=powerpoint2007
Categories=Office;Presentation;
MimeType=application/vnd.ms-powerpoint;application/vnd.openxmlformats-officedocument.presentationml.presentation;application/vnd.ms-powerpoint.presentation.macroEnabled.12;
WEOF

sudo tee /usr/share/applications/onenote2007.desktop > /dev/null <<'WEOF'
[Desktop Entry]
Name=Microsoft OneNote 2007
Comment=Microsoft Office 2007 note-taking application
Exec=/opt/winecx/launchers/onenote2007.sh %F
Type=Application
StartupNotify=true
Terminal=false
Icon=onenote2007
Categories=Office;Utility;
MimeType=application/onenote;
WEOF

sudo tee /usr/share/applications/office2007-language-settings.desktop > /dev/null <<'WEOF'
[Desktop Entry]
Name=Office 2007 Language Settings
Comment=Configure Microsoft Office 2007 display and editing languages
Exec=/opt/winecx/launchers/office2007-language-settings.sh
Type=Application
StartupNotify=true
Terminal=false
Icon=preferences-desktop-locale
Categories=Office;Settings;
WEOF

# 9. Registry Mime Type Target Mappings
cat > /tmp/fix_excel_associations.reg <<'WEOF'
Windows Registry Editor Version 5.00
[HKEY_CLASSES_ROOT\.xls]
@="Excel.Sheet.8"
[HKEY_CLASSES_ROOT\.xlsx]
@="Excel.Sheet.12"
[HKEY_CLASSES_ROOT\Excel.Sheet.8\shell\Open\command]
@="\"C:\\Program Files\\Microsoft Office\\Office12\\EXCEL.EXE\" \"%1\""
[HKEY_CLASSES_ROOT\Excel.Sheet.12\shell\Open\command]
@="\"C:\\Program Files\\Microsoft Office\\Office12\\EXCEL.EXE\" \"%1\""
[HKEY_CLASSES_ROOT\Excel.Sheet.8\shell\Open\ddeexec]
@=""
[HKEY_CLASSES_ROOT\Excel.Sheet.12\shell\Open\ddeexec]
@=""
WEOF

$WINE regedit /S /tmp/fix_excel_associations.reg

xdg-mime default word2007.desktop application/msword
xdg-mime default word2007.desktop application/vnd.openxmlformats-officedocument.wordprocessingml.document
xdg-mime default excel2007.desktop application/vnd.ms-excel
xdg-mime default excel2007.desktop application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
xdg-mime default excel2007.desktop text/csv
xdg-mime default powerpoint2007.desktop application/vnd.ms-powerpoint
xdg-mime default powerpoint2007.desktop application/vnd.openxmlformats-officedocument.presentationml.presentation

sudo update-desktop-database /usr/share/applications
if command -v xfce4-panel >/dev/null 2>&1; then xfce4-panel -r >/dev/null 2>&1 || true; fi

# Wrap-up summary panel
dialog --title 'Installation Completed' --msgbox '\nMicrosoft Office 2007 has been installed successfully!\n\nAll system parameters are fully configured. Enjoy your work!' 9 60
clear

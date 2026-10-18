#!/bin/sh
# Install fonts for Slackware 15.0

FONT_URL='https://sourceforge.net/projects/slackware-ms/files/fonts.tar.xz/download'

# When opened by double-click, start the installation in a terminal.
if [ "${1-}" != '--terminal' ] && [ ! -t 0 ]; then
    if command -v xterm >/dev/null 2>&1; then
        exec xterm -T 'Font Installation' -e sh "$0" --terminal
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --title='Font Installation' --hold -e "sh '$0' --terminal"
    else
        command -v xterm >/dev/null 2>&1 || {
            printf '%s\n' 'Could not find xterm or xfce4-terminal.' 'Install one of them and try again.'
            exit 1
        }
    fi
fi

if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo 'Error: sudo is required to install fonts.'
        read -r -p 'Press Enter to close...'
        exit 1
    fi
    exec sudo sh "$0" --terminal
fi

set -eu
WORK_DIR=$(mktemp -d /tmp/slackware-fonts.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
ARCHIVE="$WORK_DIR/fonts.tar.xz"
FONTS="$WORK_DIR/fonts"

printf '%s\n' 'Downloading fonts...'
if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 2 "$FONT_URL" -o "$ARCHIVE"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$ARCHIVE" "$FONT_URL"
else
    echo 'Error: install curl or wget.'
    read -r -p 'Press Enter to close...'
    exit 1
fi

mkdir -p "$FONTS"
echo 'Extracting the archive...'
tar -xJf "$ARCHIVE" -C "$FONTS"

if ! find "$FONTS" -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print -quit | grep -q .; then
    echo 'Error: the archive does not contain OTF or TTF fonts.'
    read -r -p 'Press Enter to close...'
    exit 1
fi

mkdir -p /usr/share/fonts/OTF /usr/share/fonts/TTF
find "$FONTS" -type f -iname '*.otf' -exec cp -f '{}' /usr/share/fonts/OTF/ \;
find "$FONTS" -type f -iname '*.ttf' -exec cp -f '{}' /usr/share/fonts/TTF/ \;
chmod 644 /usr/share/fonts/OTF/* /usr/share/fonts/TTF/* 2>/dev/null || true

echo 'Refreshing the font cache...'
fc-cache -f

echo 'Done! The fonts have been installed.'
read -r -p 'Press Enter to close...'

#!/bin/bash

VERSION_SLACKWARE=15.0

# Verificăm dacă suntem root; dacă nu, ne relansăm automat cu sudo
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Reținem directorul curent de unde am pornit scriptul
BASE_DIR=$(pwd)
WORK_DIR="${BASE_DIR}/multilib_temp_dir"

# Măsură de siguranță: Ștergem folderul temporar la ieșirea din script, indiferent de succes/eroare
cleanup() {
    echo "Se curăță fișierele temporare..."
    cd "$BASE_DIR"
    if [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

# Creăm și intrăm în folderul temporar
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo "Se descarcă pachetele multilib pentru Slackware ${VERSION_SLACKWARE}..."
lftp -c "open http://bear.alienbase.nl/mirrors/people/alien/multilib/; mirror -c -e ${VERSION_SLACKWARE}"

# Intrăm în folderul descărcat (multilib_temp_dir/15.0)
cd "${VERSION_SLACKWARE}"

echo "Se instalează pachetele multilib principale..."
upgradepkg --reinstall --install-new *.t?z

echo "Se instalează pachetele compat32..."
upgradepkg --install-new slackware64-compat32/*-compat32/*.t?z

# Configurarea blacklist-ului pentru slackpkg (verificăm să nu existe deja)
if ! grep -q "\[0-9\]+alien" /etc/slackpkg/blacklist; then
    cat >> /etc/slackpkg/blacklist <<EOF

# Pachete Multilib AlienBob
[0-9]+alien
[0-9]+compat32
EOF
fi

echo "DONE! Multilib a fost instalat cu succes, iar curățenia a fost făcută."

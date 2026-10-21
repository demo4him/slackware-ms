#!/bin/bash
# KISS Prompt Installer - Slackware / Salix

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with: sudo $0"
    exit 1
fi

USER_NAME="${SUDO_USER:-}"

if [ -z "$USER_NAME" ] || [ "$USER_NAME" = root ]; then
    read -r -p "Normal username [marius]: " USER_NAME
    USER_NAME="${USER_NAME:-marius}"
fi

USER_INFO=$(getent passwd "$USER_NAME") || {
    echo "Error: user not found: $USER_NAME"
    exit 1
}

USER_HOME=$(printf '%s\n' "$USER_INFO" | cut -d: -f6)

if [ ! -d "$USER_HOME" ]; then
    echo "Error: home directory not found."
    exit 1
fi

# Install shared prompt configuration
cat > /etc/profile.d/kiss-prompt.sh <<'EOF'
case "$-" in
    *i*)
        if [ -n "${BASH_VERSION:-}" ]; then
            if [ "$EUID" -eq 0 ]; then
                PS1='\[\e[1;31m\][\u@\h \w]#\[\e[0m\] '
            else
                PS1='\[\e[1;32m\][\u@\h \w]$\[\e[0m\] '
            fi
        fi
        ;;
esac
EOF

# Add the loader once, preserving existing configuration
add_loader() {
    file="$1"
    mkdir -p "$(dirname "$file")"
    touch "$file"

    if ! grep -Fq '# KISS prompt loader' "$file"; then
        if [ ! -e "$file.bak" ]; then
            cp -p "$file" "$file.bak"
        fi

        cat >> "$file" <<'EOF'

# KISS prompt loader
[ -r /etc/profile.d/kiss-prompt.sh ] && . /etc/profile.d/kiss-prompt.sh
EOF
    fi
}

add_loader "$USER_HOME/.bashrc"
add_loader "$USER_HOME/.bash_profile"
add_loader "/root/.bashrc"
add_loader "/root/.bash_profile"

echo
echo "KISS prompt installed successfully."
echo "User: $USER_NAME (green)"
echo "Root: red"
echo "Open a new terminal, then test with: sudo -i"
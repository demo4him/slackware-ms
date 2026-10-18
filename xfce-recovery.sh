#!/bin/bash
# KISS XFCE configuration backup and restore for Slackware/Salix.
# Runs as the current user; never uses sudo or changes system-wide files.

set -u

BACKUP_DIR="${HOME}/.local/share/xfce-recovery/backups"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"

# Only these paths inside the current user's HOME are handled.
PATHS=(
    ".config/xfce4"
    ".config/xfconf/xfce-perchannel-xml"
    ".config/autostart"
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".themes"
    ".icons"
    ".local/share/themes"
    ".local/share/icons"
    ".local/share/fonts"
    ".fonts"
)

pause() {
    printf '\nPress Enter to continue...'
    read -r _
}

show_panel_status() {
    local archive="${1:-}"
    local panel=".config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"

    if [[ -n "$archive" && -f "$archive" ]] &&
       tar -tzf "$archive" 2>/dev/null | grep -Fxq "$panel"; then
        echo "XFCE panel configuration is included in this backup:"
        echo "$panel"
    elif [[ -f "${HOME}/${panel}" ]]; then
        echo "XFCE panel configuration exists at:"
        echo "${HOME}/${panel}"
        echo "It is covered by the .config/xfce4 backup."
    else
        echo "Notice: xfce4-panel.xml was not found at the standard location."
        echo "The script will still back up .config/xfce4 if present."
    fi
}

make_backup() {
    local output="$1"
    local existing=()
    local item

    for item in "${PATHS[@]}"; do
        if [[ -d "${HOME}/${item}" && ! -L "${HOME}/${item}" ]]; then
            existing+=("$item")
        fi
    done

    if ((${#existing[@]} == 0)); then
        echo "No supported XFCE configuration, theme, icon, or font folders were found."
        return 1
    fi

    mkdir -p "$BACKUP_DIR" || {
        echo "Error: cannot create backup directory: $BACKUP_DIR"
        return 1
    }

    if tar -czf "$output" -C "$HOME" "${existing[@]}"; then
        echo "Backup created:"
        echo "$output"
        show_panel_status "$output"
        return 0
    else
        echo "Error: backup failed."
        rm -f -- "$output"
        return 1
    fi
}

do_backup() {
    local output="${BACKUP_DIR}/xfce-backup-${TIMESTAMP}.tar.gz"
    make_backup "$output"
}

do_restore() {
    local files=()
    local selected
    local archive
    local temp
    local member
    local valid
    local item

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backup directory found:"
        echo "$BACKUP_DIR"
        return 1
    fi

    shopt -s nullglob
    files=("$BACKUP_DIR"/xfce-backup-*.tar.gz)
    shopt -u nullglob

    if ((${#files[@]} == 0)); then
        echo "No backups found in:"
        echo "$BACKUP_DIR"
        return 1
    fi

    echo "Available backups:"
    for i in "${!files[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "$(basename "${files[$i]}")"
    done
    echo "  0) Cancel"
    printf '\nChoose a backup to restore: '
    read -r selected

    [[ "$selected" == "0" ]] && return 0
    [[ "$selected" =~ ^[0-9]+$ ]] || {
        echo "Invalid selection."
        return 1
    }

    ((selected >= 1 && selected <= ${#files[@]})) || {
        echo "Invalid selection."
        return 1
    }

    archive="${files[$((selected - 1))]}"

    echo
    echo "Selected: $(basename "$archive")"
    echo "This overlays backed-up files in your HOME directory."
    echo "It does not delete extra files created after the backup."
    printf 'Continue? [y/N] '
    read -r answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || {
        echo "Restore cancelled."
        return 0
    }

    # Preserve the current state before restoring.
    echo
    echo "Creating a safety backup of the current configuration..."
    if ! make_backup "${BACKUP_DIR}/xfce-before-restore-${TIMESTAMP}.tar.gz"; then
        echo "Safety backup failed; restore cancelled."
        return 1
    fi

    temp="$(mktemp -d "${TMPDIR:-/tmp}/xfce-restore.XXXXXX")" || {
        echo "Error: cannot create temporary directory."
        return 1
    }
    trap 'rm -rf -- "$temp"' RETURN

    # Reject absolute paths and parent-directory traversal before extraction.
    while IFS= read -r member; do
        member="${member#./}"
        if [[ "$member" == /* || "$member" == ".." || "$member" == ../* || "$member" == */../* || "$member" == */.. ]]; then
            echo "Unsafe path found in archive; restore cancelled."
            return 1
        fi

        valid=0
        for item in "${PATHS[@]}"; do
            if [[ "$member" == "$item" || "$member" == "$item/"* ]]; then
                valid=1
                break
            fi
        done
        if ((valid == 0)); then
            echo "Unexpected path in archive: $member"
            echo "Restore cancelled."
            return 1
        fi
    done < <(tar -tzf "$archive") || {
        echo "Error: cannot read backup archive."
        return 1
    }

    if ! tar -xzf "$archive" -C "$temp"; then
        echo "Error: could not extract backup."
        return 1
    fi

    # Copy only the allowlisted paths. No system-wide locations are touched.
    for item in "${PATHS[@]}"; do
        if [[ -d "${temp}/${item}" && ! -L "${temp}/${item}" ]]; then
            mkdir -p "${HOME}/${item}" || {
                echo "Error: cannot create destination directory."
                return 1
            }
            cp -a "${temp}/${item}/." "${HOME}/${item}/" || {
                echo "Error restoring: $item"
                return 1
            }
        fi
    done

    echo
    echo "Restore completed."
    show_panel_status
    echo "Log out and log back in, or restart XFCE, to apply relevant changes."
    echo "If anything looks wrong, restore the safety backup created just now."
    return 0
}

while true; do
    clear 2>/dev/null || true
    cat <<'MENU'
====================================
       XFCE Recovery - KISS
       Slackware / Salix Linux
====================================

1) Backup XFCE settings, panel, themes, icons and user fonts
2) Restore settings and panel from a backup
3) Exit

MENU
    printf 'Choose an option [1-3]: '
    read -r choice

    case "$choice" in
        1)
            echo
            do_backup
            pause
            ;;
        2)
            echo
            do_restore
            pause
            ;;
        3)
            exit 0
            ;;
        *)
            echo "Invalid option."
            pause
            ;;
    esac
done

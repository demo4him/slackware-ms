#!/bin/bash
# Slackware KISS - Kernel Artifact Cleaner
# Select a kernel version, review its artifacts, then remove them safely.

set -uo pipefail

VERSION=""
TARGETS=()
GRUB_CFG=""
GRUB_BACKUP=""

need_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo "ERROR: Run this script as root (for example: sudo $0)." >&2
        exit 1
    fi
}

pause_to_close() {
    if [[ -t 0 ]]; then
        read -r -p "Press Enter to close..." _ || true
    fi
}

select_kernel() {
    local current rc
    current="$(uname -r)"

    while :; do
        if command -v dialog >/dev/null 2>&1; then
            VERSION="$(dialog --clear --title "Kernel Artifact Cleaner" \
                --inputbox "Enter the kernel version to clean.\n\nExample: 6.12.110\n\nRunning kernel: $current" \
                12 62 2>&1 >/dev/tty)"
            rc=$?
            clear
            if [[ $rc -ne 0 || -z "$VERSION" ]]; then
                echo "Operation cancelled."
                exit 0
            fi
        else
            echo "Kernel Artifact Cleaner"
            echo "Running kernel: $current"
            read -r -p "Enter the kernel version to clean: " VERSION || true
            [[ -n "$VERSION" ]] || { echo "Operation cancelled."; exit 0; }
        fi

        # Accept common numeric kernel versions and optional local suffixes only.
        if [[ ! "$VERSION" =~ ^[0-9]+([.][0-9]+){1,3}([A-Za-z0-9._+-]*)?$ ]]; then
            if command -v dialog >/dev/null 2>&1; then
                dialog --title "Invalid Version" --msgbox "Enter a valid kernel version, such as 6.12.110 or 6.12.110-custom." 8 66
                clear
            else
                echo "ERROR: Invalid kernel version format."
            fi
            continue
        fi
        break
    done

    if [[ "$VERSION" == "$current" ]]; then
        echo "ERROR: The currently running kernel ($VERSION) cannot be deleted."
        pause_to_close
        exit 1
    fi
}

show_header() {
    clear 2>/dev/null || true
    echo "=============================================="
    echo " Slackware KISS Kernel Artifact Cleaner"
    echo "=============================================="
    echo "Target kernel: $VERSION"
    echo
}

collect_targets() {
    TARGETS=()
    [[ -d "/lib/modules/$VERSION" ]] && TARGETS+=("/lib/modules/$VERSION")
    [[ -f "/boot/vmlinuz-$VERSION" ]] && TARGETS+=("/boot/vmlinuz-$VERSION")
    [[ -f "/boot/vmlinuz-generic-$VERSION" ]] && TARGETS+=("/boot/vmlinuz-generic-$VERSION")
    [[ -f "/boot/vmlinuz-huge-$VERSION" ]] && TARGETS+=("/boot/vmlinuz-huge-$VERSION")
    [[ -f "/boot/System.map-$VERSION" ]] && TARGETS+=("/boot/System.map-$VERSION")
    [[ -f "/boot/System.map-generic-$VERSION" ]] && TARGETS+=("/boot/System.map-generic-$VERSION")
    [[ -f "/boot/System.map-huge-$VERSION" ]] && TARGETS+=("/boot/System.map-huge-$VERSION")
    [[ -f "/boot/config-$VERSION" ]] && TARGETS+=("/boot/config-$VERSION")
    [[ -f "/boot/config-generic-$VERSION" ]] && TARGETS+=("/boot/config-generic-$VERSION")
    [[ -f "/boot/config-huge-$VERSION" ]] && TARGETS+=("/boot/config-huge-$VERSION")
    [[ -f "/boot/initrd-$VERSION.gz" ]] && TARGETS+=("/boot/initrd-$VERSION.gz")
    [[ -f "/boot/initrd-generic-$VERSION.gz" ]] && TARGETS+=("/boot/initrd-generic-$VERSION.gz")
    [[ -d "/usr/src/linux-$VERSION" ]] && TARGETS+=("/usr/src/linux-$VERSION")
}

find_grub_config() {
    local candidate
    GRUB_CFG=""
    command -v grub-mkconfig >/dev/null 2>&1 || return 1

    for candidate in \
        /boot/grub/grub.cfg \
        /boot/grub2/grub.cfg \
        /boot/efi/EFI/Slackware/grub.cfg \
        /boot/efi/EFI/slackware/grub.cfg \
        /boot/EFI/Slackware/grub.cfg \
        /boot/EFI/slackware/grub.cfg; do
        if [[ -f "$candidate" ]]; then
            GRUB_CFG="$candidate"
            return 0
        fi
    done

    # Search common EFI directories without assuming a vendor-specific name.
    for candidate in /boot/efi/EFI/*/grub.cfg /boot/EFI/*/grub.cfg; do
        if [[ -f "$candidate" ]]; then
            GRUB_CFG="$candidate"
            return 0
        fi
    done
    return 1
}

show_targets() {
    echo "Kernel artifacts found:"
    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        echo "  No artifacts found for $VERSION."
        return
    fi
    printf '  %s\n' "${TARGETS[@]}"
    echo

    if find_grub_config; then
        echo "GRUB configuration: $GRUB_CFG"
        echo "The configuration will be regenerated after cleanup, if possible."
    else
        echo "GRUB configuration not detected; no GRUB changes will be attempted."
    fi
    echo
}

confirm_delete() {
    local prompt
    prompt="Delete only the listed artifacts for kernel $VERSION?\n\nIf GRUB is detected, its generated configuration will be backed up and regenerated afterward."
    if command -v dialog >/dev/null 2>&1; then
        dialog --title "Confirm Kernel Cleanup" --yesno "$prompt" 12 72
        return $?
    fi
    read -r -p "Delete the listed artifacts and refresh GRUB if available? [y/N] " ans
    [[ "${ans:-}" =~ ^[Yy]$ ]]
}

delete_targets() {
    local item failed=0
    echo "Deleting kernel artifacts..."
    for item in "${TARGETS[@]}"; do
        echo "Removing: $item"
        if [[ -d "$item" ]]; then
            rm -rf -- "$item" || failed=1
        else
            rm -f -- "$item" || failed=1
        fi
    done
    return "$failed"
}

refresh_grub() {
    local stamp tmp
    if ! find_grub_config; then
        echo "GRUB refresh skipped: grub-mkconfig or a known GRUB configuration was not found."
        return 0
    fi

    stamp="$(date +%Y%m%d-%H%M%S)"
    GRUB_BACKUP="${GRUB_CFG}.backup-${stamp}"
    if ! cp -a -- "$GRUB_CFG" "$GRUB_BACKUP"; then
        echo "WARNING: Could not back up $GRUB_CFG; GRUB was not changed."
        return 1
    fi

    echo "Backed up GRUB configuration to: $GRUB_BACKUP"
    tmp="$(mktemp "${GRUB_CFG}.tmp.XXXXXX")" || {
        echo "WARNING: Could not create a temporary GRUB configuration file."
        return 1
    }

    if grub-mkconfig -o "$tmp"; then
        if mv -f -- "$tmp" "$GRUB_CFG"; then
            echo "GRUB configuration regenerated: $GRUB_CFG"
            echo "Automatically generated entries for removed kernel files should no longer appear."
            echo "Custom entries in /etc/grub.d/40_custom may need separate manual review."
            return 0
        fi
    fi

    rm -f -- "$tmp"
    cp -a -- "$GRUB_BACKUP" "$GRUB_CFG" 2>/dev/null || true
    echo "WARNING: GRUB regeneration failed. The previous configuration was restored where possible."
    echo "Backup: $GRUB_BACKUP"
    return 1
}

verify() {
    local remaining=0 item
    echo
    echo "=============================================="
    echo " Verification"
    echo "=============================================="
    for item in \
        "/lib/modules/$VERSION" "/boot/vmlinuz-$VERSION" "/boot/vmlinuz-generic-$VERSION" \
        "/boot/vmlinuz-huge-$VERSION" "/boot/System.map-$VERSION" "/boot/System.map-generic-$VERSION" \
        "/boot/System.map-huge-$VERSION" "/boot/config-$VERSION" "/boot/config-generic-$VERSION" \
        "/boot/config-huge-$VERSION" "/boot/initrd-$VERSION.gz" "/boot/initrd-generic-$VERSION.gz" \
        "/usr/src/linux-$VERSION"; do
        if [[ -e "$item" ]]; then
            echo "WARNING: Artifact still exists: $item"
            remaining=1
        fi
    done
    [[ $remaining -eq 0 ]] && echo "Kernel artifacts removed for version $VERSION."
    echo "Current kernel: $(uname -r)"
}

main() {
    need_root
    select_kernel
    show_header
    collect_targets
    show_targets

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        echo "Nothing will be deleted."
        pause_to_close
        exit 0
    fi

    if ! confirm_delete; then
        echo "Operation cancelled."
        exit 0
    fi

    if ! delete_targets; then
        echo "WARNING: One or more kernel artifacts could not be removed."
    fi
    refresh_grub || true
    verify
    pause_to_close
}

main "$@"

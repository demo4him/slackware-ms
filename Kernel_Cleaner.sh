#!/bin/bash
#
# Slackware KISS - Kernel Artifact Cleaner
# Kernel version is selected dynamically from installed artifacts.
#

set -uo pipefail

VERSION=""
TARGETS=()

select_kernel() {
    local current
    current="$(uname -r)"

    if command -v dialog >/dev/null 2>&1; then
        VERSION="$(
            dialog \
                --clear \
                --title "Kernel Artifact Cleaner" \
                --inputbox \
                "Enter the kernel version to clean:\n\nExample: 6.12.110\n\nRunning kernel: $current" \
                12 60 \
                2>&1 >/dev/tty
        )"
        local rc=$?

        clear

        [[ $rc -eq 0 && -n "$VERSION" ]] || {
            echo "Operation cancelled."
            exit 0
        }
    else
        echo "Kernel Artifact Cleaner"
        echo
        echo "Running kernel: $current"
        echo
        read -r -p "Enter the kernel version to clean: " VERSION

        [[ -n "$VERSION" ]] || {
            echo "Operation cancelled."
            exit 0
        }
    fi

    if [[ "$VERSION" == "$current" ]]; then
        clear
        echo "=============================================="
        echo " ERROR"
        echo "=============================================="
        echo
        echo "You selected the currently running kernel:"
        echo
        echo "  $VERSION"
        echo
        echo "This kernel cannot be deleted."
        echo
        read -r -p "Press Enter to close..."
        exit 1
    fi
}

show_header() {
    clear
    echo "=============================================="
    echo " Slackware KISS Kernel Artifact Cleaner"
    echo "=============================================="
    echo
    echo "Target kernel: $VERSION"
    echo
}

collect_targets() {
    TARGETS=()

    [[ -d "/lib/modules/$VERSION" ]] &&
        TARGETS+=("/lib/modules/$VERSION")

    [[ -f "/boot/vmlinuz-$VERSION" ]] &&
        TARGETS+=("/boot/vmlinuz-$VERSION")

    [[ -f "/boot/System.map-$VERSION" ]] &&
        TARGETS+=("/boot/System.map-$VERSION")

    [[ -f "/boot/config-$VERSION" ]] &&
        TARGETS+=("/boot/config-$VERSION")

    [[ -f "/boot/initrd-$VERSION.gz" ]] &&
        TARGETS+=("/boot/initrd-$VERSION.gz")

    [[ -f "/boot/initrd-generic-$VERSION.gz" ]] &&
        TARGETS+=("/boot/initrd-generic-$VERSION.gz")

    [[ -d "/usr/src/linux-$VERSION" ]] &&
        TARGETS+=("/usr/src/linux-$VERSION")
}

show_targets() {
    echo "Found artifacts:"
    echo

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        echo "  No artifacts found for $VERSION."
        return
    fi

    local item
    for item in "${TARGETS[@]}"; do
        echo "  $item"
    done

    echo
}

confirm_delete() {
    if command -v dialog >/dev/null 2>&1; then
        dialog \
            --title "Kernel Artifact Cleaner" \
            --yesno \
"ONLY the following kernel artifacts will be deleted:

$VERSION

Continue?" 15 70

        return $?
    fi

    read -r -p "Delete these artifacts? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

delete_targets() {
    local item

    echo
    echo "Deleting..."

    for item in "${TARGETS[@]}"; do
        echo "Removing: $item"

        if [[ -d "$item" ]]; then
            rm -rf -- "$item"
        else
            rm -f -- "$item"
        fi
    done
}

verify() {
    echo
    echo "=============================================="
    echo " Verification"
    echo "=============================================="
    echo

    if [[ -d "/lib/modules/$VERSION" ||
          -f "/boot/vmlinuz-$VERSION" ||
          -f "/boot/System.map-$VERSION" ||
          -f "/boot/config-$VERSION" ||
          -f "/boot/initrd-$VERSION.gz" ||
          -f "/boot/initrd-generic-$VERSION.gz" ||
          -d "/usr/src/linux-$VERSION" ]]; then
        echo "WARNING: some artifacts $VERSION still exist."
    else
        echo "OK: the artifacts $VERSION have been removed."
    fi

    echo
    echo "Current kernel:"
    uname -r
    echo
}

main() {
    need_root
    select_kernel || exit 0
    show_header
    collect_targets
    show_targets

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        if command -v dialog >/dev/null 2>&1; then
            dialog \
                --clear \
                --title "Kernel Artifact Cleaner" \
                --msgbox \
                "NO KERNEL ARTIFACTS FOUND.

Kernel version:
$VERSION

Nothing will be deleted.

The script will now close." \
                12 60
            clear
        else
            echo
            echo "=============================================="
            echo " NO KERNEL ARTIFACTS FOUND"
            echo "=============================================="
            echo
            echo "Kernel version: $VERSION"
            echo
            echo "Nothing will be deleted."
            echo
            read -r -p "Press Enter to close..."
        fi
        exit 0
    fi

    if ! confirm_delete; then
        clear
        echo "Operation cancelled."
        exit 0
    fi

    delete_targets
    verify

    if command -v dialog >/dev/null 2>&1; then
        dialog \
            --clear \
            --title "Kernel Artifact Cleaner" \
            --msgbox \
            "Kernel cleanup finished.

Selected kernel:
$VERSION

The script will now close." \
            11 60
        clear
    else
        echo
        echo "=============================================="
        echo " Kernel cleanup finished."
        echo " Selected kernel: $VERSION"
        echo "=============================================="
        echo
        read -r -p "Press Enter to close..."
    fi
}

main "$@"
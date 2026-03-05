#!/bin/bash

function list_installed_kernels_boot() {
    echo "Kernel versions installed in /boot:"
    # List the installed kernel versions in /boot
    for file in /boot/vmlinuz-generic*; do
        version=$(echo "$file" | cut -d'-' -f3)
        echo "$version"
    done
}

function list_kernels_lib() {
    if [ -d "/lib/modules" ]; then
        echo "Kernel versions installed in /lib/modules:"
        # List the installed kernel versions in /lib/modules
        for dir in /lib/modules/*/; do
            version=$(basename "$dir")
            echo "$version"
        done
    else
        echo "The /lib/modules directory does not exist."
    fi
}

function list_kernels_usr_src() {
    if [ -d "/usr/src" ]; then
        echo "Kernel versions installed in /usr/src:"
        # List the installed kernel versions in /usr/src
        for dir in /usr/src/linux*/; do
            version=$(basename "$dir")
            echo "$version"
        done
    else
        echo "The /usr/src directory does not exist."
    fi
}

function remove_kernel() {
    read -rp "Which kernel do you want to delete? " kernel_to_remove
    # Check if the entered kernel is installed
    if [ -e "/boot/vmlinuz-generic-$kernel_to_remove" ]; then
        # Remove the files corresponding to the selected kernel in /boot
        rm -f "/boot/vmlinuz-generic-$kernel_to_remove" "/boot/System.map-generic-$kernel_to_remove" "/boot/config-generic-$kernel_to_remove"
        echo "Kernel $kernel_to_remove has been removed from /boot."
    else
        echo "The entered kernel version is not installed in /boot."
    fi

    if [ -e "/lib/modules/$kernel_to_remove" ]; then
        # Remove the directory corresponding to the selected kernel in /lib/modules
        rm -rf "/lib/modules/$kernel_to_remove"
        echo "Kernel $kernel_to_remove has been removed from /lib/modules."
    else
        echo "The entered kernel version is not installed in /lib/modules."
    fi

    if [ -e "/usr/src/linux-$kernel_to_remove" ]; then
        # Remove the directory corresponding to the selected kernel in /usr/src
        rm -rf "/usr/src/linux-$kernel_to_remove"
        echo "Kernel $kernel_to_remove has been removed from /usr/src."
    else
        echo "The entered kernel version is not installed in /usr/src."
    fi
}

# Show the menu
while true; do
    echo "Menu:"
    echo "1. Check if /boot exists and list installed kernel versions"
    echo "2. List installed kernel versions in /lib/modules"
    echo "3. List installed kernel versions in /usr/src that start with 'linux'"
    echo "4. Remove kernel (removes the kernel from /boot, /lib/modules and /usr/src)"
    echo "5. Exit"
    read -rp "Select an option: " option
    case $option in
        1)
            if [ -d "/boot" ]; then
                echo "The /boot directory exists."
                list_installed_kernels_boot
            else
                echo "The /boot directory does not exist."
            fi
            ;;
        2)
            list_kernels_lib
            ;;
        3)
            list_kernels_usr_src
            ;;
        4)
            remove_kernel
            ;;
        5)
            echo "Exit."
            exit 0
            ;;
        *)
            echo "Invalid option. Please select a valid option."
            ;;
    esac
done

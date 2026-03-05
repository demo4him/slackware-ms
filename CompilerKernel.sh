#!/bin/bash
#
#By cl45h, long live remote vieja
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Warning: This script must be run as root to perform some operations."
    echo "Please re-run the script with superuser privileges (sudo)."
    exit 1
fi

# Check if the current directory is /usr/src
if [ "$(pwd)" != "/usr/src" ]; then
    echo "Moving to /usr/src directory..."
    cd /usr/src || {
        echo "Error: Could not change to /usr/src directory. Make sure it exists."
        exit 1
    }
fi

# Function to build the kernel
build_kernel() {
    if [ -z "$kernel_version" ]; then
        echo "Error: You must enter the kernel version first."
        return
    fi

    cd "linux-$kernel_version" || {
        echo "Error: Could not change to directory linux-$kernel_version."
        return
    }

    # Check if the .config file already exists
    if [ ! -e ".config" ]; then
        # If it doesn't exist, try copying the configuration from /proc/config.gz
        if zcat /proc/config.gz > .config; then
            echo "Configuration file (.config) created successfully."
        else
            echo "Error: Could not create the configuration file (.config) from /proc/config.gz."
            return
        fi
    else
        echo "The configuration file (.config) already exists."
    fi

    # Run make olddefconfig
    if make olddefconfig; then
        echo "Kernel configuration successfully updated using make olddefconfig."
        # You can add more build commands here if necessary
    else
        echo "Error: Could not update kernel configuration with make olddefconfig."
        return
    fi

    # Ask the user for the number of cores
    read -p "Enter the number of cores to compile with (for example, 2): " cores

    # Compile the kernel with the specified number of cores
    if make -j"$cores" bzImage; then
        echo "Kernel compilation (bzImage) completed successfully with $cores cores."

        # Wait for the user to press a key before continuing
        read -n 1 -s -r -p "Press any key to continue..."

        # Compile and install modules
        if make -j"$cores" modules && make modules_install; then
            echo "Module compilation and installation completed successfully."
        else
            echo "Error: Could not compile and install modules."
        fi
    else
        echo "Error: Could not compile the kernel (bzImage) with $cores cores."
    fi
}

# Function to perform final adjustments
final_adjustments() {
    if [ -z "$kernel_version" ]; then
        echo "Error: You must enter the kernel version first."
        return
    fi

    # Copy files to /boot directory
    if [ -d "/boot" ]; then
        cp arch/x86/boot/bzImage "/boot/vmlinuz-generic-$kernel_version"
        cp System.map "/boot/System.map-generic-$kernel_version"
        cp .config "/boot/config-generic-$kernel_version"

        echo "Creating symbolic links in the boot directory. Press enter to continue."
        read -s -p ""

        # Create symbolic links
        cd /boot || {
            echo "Error: Could not change to /boot directory."
            return
        }
        rm System.map
        rm config
        ln -s "System.map-generic-$kernel_version" System.map
        ln -s "config-generic-$kernel_version" config
        cd - || return

        echo "Creating ramdisk images using preloaded modules. Press enter to continue."
        read -s -p ""

        # Create ramdisk images
        /usr/share/mkinitrd/mkinitrd_command_generator.sh -k "$kernel_version"
    else
        echo "Error: The /boot directory does not exist. Make sure /boot is created before running this script."
    fi
}

# Function for bootloader installation
bootloader_installation() {
    if [ -z "$kernel_version" ]; then
        echo "Error: You must enter the kernel version first."
        return
    fi

    # Ask the user which bootloader to install to
    read -p "Select the bootloader for installation (grub, lilo, etc.): " bootloader

    case $bootloader in
        grub)
            echo "Installing in GRUB for vmlinuz-generic-$kernel_version..."
            # GRUB-specific commands
            grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        lilo)
            echo "Installing in LILO for vmlinuz-generic-$kernel_version..."
            # LILO-specific commands
            /usr/share/mkinitrd/mkinitrd_command_generator.sh -l /boot/vmlinuz-generic-$kernel_version
            lilo -v
            ;;
        *)
            echo "Error: Unrecognized bootloader. Select a valid bootloader."
            return
            ;;
    esac

    echo "Bootloader installation completed."
}

# Validation to check if the string is a number or version format
is_valid_version() {
    local input=$1
    if [[ $input =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        return 0  # Valid version
    else
        return 1  # Invalid version
    fi
}

# Download the kernel from kernel.org and extract it
download_and_extract_kernel() {
    local version=$1
    local url="https://cdn.kernel.org/pub/linux/kernel/v${version%%.*}.x/linux-$version.tar.xz"
    if wget -q "$url"; then
        echo "Kernel version $version downloaded successfully."
        tar -xvpf "linux-$version.tar.xz"
        return 0  # Successful download and extraction
    else
        echo "Error: Kernel version $version not found on kernel.org."
        return 1  # Download error
    fi
}

# Function to install Ubuntu kernel
ubuntu_kernel() {
    echo "Select the Ubuntu kernel version you want to install:"
    
    # Base URL for Ubuntu kernels
    base_url="https://kernel.ubuntu.com/mainline/v"

    # Read kernel version from user
    read -p "Kernel version (for example, 5.15): " kernel_version

    # Build full URL
    url="${base_url}${kernel_version}/amd64/"

    # Create destination directory
    destination="./deb_packages"
    mkdir -p "$destination"

    # Download the HTML page containing links
    wget -q -O- "$url" | grep -oP '(?<=href=")[^"]*\.deb' | while read -r link; do
        # Build full URL for each .deb package
        package_url="${url}${link}"
        
        # .deb package name
        package_name="$(basename "$link")"

        # Download the .deb package into destination directory
        wget -P "$destination" "$package_url" && echo "Downloaded: $package_name"
    done

    echo "Ubuntu kernel version $kernel_version download completed in directory: $destination"
    read -p "Press enter to install the kernel"
    
    # Install .deb packages using dpkg
    cd "$destination" || exit
    sudo dpkg -i *.deb

    echo "Kernel installation completed."
    update-grub
}

# Show banner at startup
show_banner

# Main menu
while true; do
    clear  # Clear screen before showing menu
    echo "Menu:"
    echo "1. Enter kernel version to compile"
    echo "2. Build kernel"
    echo "3. Final Adjustments"
    echo "4. Bootloader Installation"
    echo "5. Install on Ubuntu"
    echo "6. Exit"

    read -p "Enter your option: " option

    case $option in
        1)
            read -p "Enter the kernel version to compile: " kernel_version
            if is_valid_version "$kernel_version"; then
                if download_and_extract_kernel "$kernel_version"; then
                    echo "Kernel version saved: $kernel_version"
                else
                    echo "Error: Kernel version does not exist on kernel.org."
                fi
            else
                echo "Error: Invalid kernel version. It must be a string of numbers and dots."
            fi
            ;;
        2)
            build_kernel
            ;;
        3)
            final_adjustments
            ;;
        4)
            bootloader_installation
            ;;
        5)
            ubuntu_kernel
            ;;
        6)
            echo "Exiting the script. See you!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a valid option."
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
done

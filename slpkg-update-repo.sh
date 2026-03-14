#!/bin/bash

FILE="/etc/slpkg/repositories.toml"

# Check if script is executed as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Check if file exists
if [[ ! -f "$FILE" ]]; then
    echo "The file $FILE does not exist."
    exit 1
fi

echo "Select the repository you want:"
echo "1) alien"
echo "2) slackel"
echo "3) ponce"
echo "4) sbo"
echo "5) salix"
echo "6) salix_extra"
echo "7) restricted"
echo "8) slackdce"

read -p "Enter the number corresponding to your selection: " choice

case $choice in
    1) new_repo="alien" ;;
    2) new_repo="slackel" ;;
    3) new_repo="ponce" ;;
    4) new_repo="sbo" ;;
    5) new_repo="salix" ;;
    6) new_repo="salix_extra" ;;
    7) new_repo="restricted" ;;
    8) new_repo="slackdce" ;;  
    *)
        echo "Invalid selection."
        exit 1
        ;;
esac

# Replace the REPOSITORY line
sed -i "s/^REPOSITORY = \".*\"/REPOSITORY = \"$new_repo\"/" "$FILE"

echo "The file has been modified. The repository is now $new_repo."

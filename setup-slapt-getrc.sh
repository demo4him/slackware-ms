#!/bin/bash

CONFIG="/etc/slapt-get/slapt-getrc"
BACKUP="${CONFIG}.bak"

echo "Configuring slapt-getrc for Slackware 15.0"

# Create a backup
if [ -f "$CONFIG" ]; then
    cp -a "$CONFIG" "$BACKUP" || exit 1
    echo "Backup created: $BACKUP"
fi

# Write configuration
cat > "$CONFIG" <<'EOF'
# Slackware 15.0 x86_64 - Slackware UK
# Official Slackware + Salix XFCE 4.20 + AlienBOB
# Multilib is managed separately and is NOT handled by slapt-get.

WORKINGDIR=/var/slapt-get

EXCLUDE=^aaa_elflibs,^aaa_base,^devs,^glibc.*,^binutils$,aaa_glibc,^e2fsprogs,^llvm,^rootuser-settings,^zzz-settings.*,-i?86-,^kernel-.*,.*_multilib-.*,^mozilla-firefox.*,.*slackdce,.*SBo,^glib2$

SOURCE=https://slackware.uk/slackware/slackware64-15.0/:OFFICIAL
SOURCE=https://slackware.uk/slackware/slackware64-15.0/patches/:OFFICIAL
SOURCE=https://slackware.uk/slackware/slackware64-15.0/extra/:OFFICIAL
SOURCE=https://slackware.uk/salix/x86_64/xfce4.20-15.0/:PREFERRED
SOURCE=https://slackware.uk/people/alien/sbrepos/15.0/x86_64/:DEFAULT
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: Could not write $CONFIG"
    exit 1
fi

echo
echo "slapt-getrc configured successfully!"

# Retrieve and import GPG keys for configured sources
echo
echo "Retrieving GPG keys for configured sources..."

slapt-get --add-keys

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to retrieve one or more GPG keys."
    exit 1
fi

echo
echo "Configuration completed successfully!"
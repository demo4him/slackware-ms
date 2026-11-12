#!/bin/sh
#
# Refresh font, icon and MIME caches.
# Run as root after installing or removing packages.

# Update font cache.
if [ -x /usr/bin/fc-cache ]; then
    echo "Updating font cache..."
    /usr/bin/fc-cache -f
fi

# Update icon caches only for themes that already have a cache file.
if [ -d /usr/share/icons ] && [ -x /usr/bin/gtk-update-icon-cache ]; then
    for theme_dir in /usr/share/icons/*; do
        [ -d "$theme_dir" ] || continue

        if [ -r "$theme_dir/icon-theme.cache" ]; then
            echo "Updating icon cache in $theme_dir..."
            /usr/bin/gtk-update-icon-cache -t -f "$theme_dir" \
                >/dev/null 2>&1
        fi
    done

    # Remove an icon cache placed directly in /usr/share/icons.
    if [ -r /usr/share/icons/icon-theme.cache ]; then
        echo "Removing /usr/share/icons/icon-theme.cache..."
        rm -f /usr/share/icons/icon-theme.cache
    fi
fi

# Update the MIME database.
if [ -x /usr/bin/update-mime-database ] && [ -d /usr/share/mime ]; then
    echo "Updating MIME database..."
    /usr/bin/update-mime-database /usr/share/mime
fi

exit 0

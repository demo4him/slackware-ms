#!/bin/sh
# KISS XFCE speed profile: disable compositing only.
# No GTK CSS, theme, panel, animation, or application settings are changed.
set -eu

if ! command -v xfconf-query >/dev/null 2>&1; then
    printf '%s\n' "Error: xfconf-query not found; no changes made." >&2
    exit 1
fi

printf '%s\n' "Applying XFCE speed profile..."

if xfconf-query -c xfwm4 -p /general/use_compositing >/dev/null 2>&1; then
    xfconf-query -c xfwm4 -p /general/use_compositing -s false
else
    xfconf-query -c xfwm4 -p /general/use_compositing --create --type=bool --set=false
fi

# Stop xcompmgr if running; it is an external compositor.
if command -v pkill >/dev/null 2>&1; then
    pkill -x xcompmgr 2>/dev/null || true
fi

printf '\n%s\n' "Done."
printf '%s\n' "XFCE compositing is disabled and xcompmgr is stopped if it was running."
printf '%s\n' "No appearance files or GTK settings were touched."
printf '%s\n' "To apply the session setting fully, log out and back in if needed."

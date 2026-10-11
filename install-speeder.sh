#!/bin/sh
#
# install-speeder
#
# Slackware 15.0 Stable
#
# Installs:
#   /usr/local/sbin/slackboot-optimize
#   /usr/local/sbin/speeder-2.0
#
# Integrates speeder-2.0 into /etc/rc.d/rc.M
#
# POSIX sh + KISS
#
# Does NOT:
#   - run slackboot-optimize apply
#   - change rc.d executable bits
#   - modify rc.inet1 or rc.inet2
#   - use systemd
#   - scan services
#   - replace rc.M wholesale
#

PATH=/sbin:/usr/sbin:/bin:/usr/bin

RCM=/etc/rc.d/rc.M
SB=/usr/local/sbin/slackboot-optimize
SP=/usr/local/sbin/speeder-2.0
BACKUP_DIR=/var/backups/install-speeder

die()
{
    echo "ERROR: $*" >&2
    exit 1
}

need_root()
{
    [ "$(id -u)" = 0 ] ||
        die "Run this script as root."
}

check_file()
{
    file="$1"

    [ -f "$file" ] ||
        die "Missing file: $file"

    sh -n "$file" ||
        die "Syntax check failed: $file"
}

backup_rcm()
{
    mkdir -p "$BACKUP_DIR" ||
        die "Cannot create $BACKUP_DIR"

    stamp="$(date '+%Y%m%d-%H%M%S')"

    backup="$BACKUP_DIR/rc.M.$stamp"

    cp -p "$RCM" "$backup" ||
        die "Cannot backup $RCM"

    echo "$backup"
}

install_slackboot()
{
    echo "Installing slackboot-optimize..."

    cat > "$SB" <<'EOF'
#!/bin/sh
#
# slackboot-optimize
#
# Slackware 15.0 - conservative boot parallelization
#
# Parallelizes only independently verified leaf services.
# Does NOT use systemd, ionice, service scanners, or generic rc.d runners.
#

PATH=/sbin:/usr/sbin:/bin:/usr/bin

RCM=/etc/rc.d/rc.M
RCINET2=/etc/rc.d/rc.inet2
BACKUP_DIR=/var/backups/slackboot-optimize

die()
{
    echo "ERROR: $*" >&2
    exit 1
}

need_root()
{
    [ "$(id -u)" = 0 ] || die "Run this script as root."
}

backup_file()
{
    file="$1"
    stamp="$2"

    [ -f "$file" ] || die "Missing file: $file"

    cp -p "$file" "$BACKUP_DIR/$(basename "$file").$stamp" ||
        die "Cannot backup $file"
}

check_file()
{
    file="$1"

    [ -f "$file" ] || die "Missing file: $file"

    echo "Checking syntax: $file"

    sh -n "$file" ||
        die "Syntax check FAILED: $file"

    echo "OK: $file"
}

check_all()
{
    check_file "$RCM"
    check_file "$RCINET2"

    echo
    echo "Syntax check: OK"
}

replace_line()
{
    file="$1"
    old="$2"
    new="$3"

    tmp="${file}.slackboot.$$"
    tmp2="${tmp}.new"

    cp -p "$file" "$tmp" ||
        die "Cannot create temporary copy of $file"

    awk -v old="$old" -v new="$new" '
        $0 == old {
            print new
            found++
            next
        }
        { print }
        END {
            if (found > 1)
                exit 2
        }
    ' "$file" > "$tmp2"

    rc=$?

    if [ "$rc" -eq 2 ]; then
        rm -f "$tmp" "$tmp2"
        die "Ambiguous match in $file:
  $old"
    fi

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmp" "$tmp2"
        die "Could not process $file"
    fi

    cat "$tmp2" > "$tmp" ||
        {
            rm -f "$tmp" "$tmp2"
            die "Cannot update temporary file for $file"
        }

    rm -f "$tmp2"

    if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
        return 0
    fi

    mv "$tmp" "$file" ||
        {
            rm -f "$tmp"
            die "Cannot replace $file"
        }
}

already_optimized()
{
    grep -Fqx '  /etc/rc.d/rc.inetd start &' "$RCINET2" &&
    grep -Fqx '  /etc/rc.d/rc.sshd start &' "$RCINET2" &&
    grep -Fqx '  /etc/rc.d/rc.bind start &' "$RCINET2" &&
    grep -Fqx '  /etc/rc.d/rc.acpid start &' "$RCM" &&
    grep -Fqx '  /etc/rc.d/rc.cups start &' "$RCM" &&
    grep -Fqx '  /etc/rc.d/rc.crond start &' "$RCM" &&
    grep -Fqx '  /etc/rc.d/rc.atd start &' "$RCM" &&
    grep -Fqx '  /etc/rc.d/rc.postfix start &' "$RCM" &&
    grep -Fqx '  /etc/rc.d/rc.gpm start &' "$RCM"
}

apply_changes()
{
    need_root

    [ -f "$RCM" ] ||
        die "Missing file: $RCM"

    [ -f "$RCINET2" ] ||
        die "Missing file: $RCINET2"

    check_all

    if already_optimized; then
        echo
        echo "=========================================="
        echo " slackboot-optimize: ALREADY OPTIMIZED"
        echo "=========================================="
        echo
        echo "No changes made."
        echo "No new backup created."
        echo
        return 0
    fi

    mkdir -p "$BACKUP_DIR" ||
        die "Cannot create $BACKUP_DIR"

    stamp="$(date '+%Y%m%d-%H%M%S')"

    echo
    echo "Creating backups..."

    backup_file "$RCM" "$stamp"
    backup_file "$RCINET2" "$stamp"

    echo
    echo "Optimizing rc.inet2..."

    replace_line "$RCINET2" \
        '  /etc/rc.d/rc.inetd start' \
        '  /etc/rc.d/rc.inetd start &'

    replace_line "$RCINET2" \
        '  /etc/rc.d/rc.sshd start' \
        '  /etc/rc.d/rc.sshd start &'

    replace_line "$RCINET2" \
        '  /etc/rc.d/rc.bind start' \
        '  /etc/rc.d/rc.bind start &'

    echo
    echo "Optimizing rc.M..."

    replace_line "$RCM" \
        '  /etc/rc.d/rc.acpid start' \
        '  /etc/rc.d/rc.acpid start &'

    replace_line "$RCM" \
        '  /etc/rc.d/rc.cups start' \
        '  /etc/rc.d/rc.cups start &'

    replace_line "$RCM" \
        '  /etc/rc.d/rc.crond start' \
        '  /etc/rc.d/rc.crond start &'

    replace_line "$RCM" \
        '  /etc/rc.d/rc.atd start' \
        '  /etc/rc.d/rc.atd start &'

    replace_line "$RCM" \
        '  /etc/rc.d/rc.postfix start' \
        '  /etc/rc.d/rc.postfix start &'

    replace_line "$RCM" \
        '  /etc/rc.d/rc.gpm start' \
        '  /etc/rc.d/rc.gpm start &'

    echo
    echo "Checking modified files..."

    check_all

    echo
    echo "=========================================="
    echo " slackboot-optimize: APPLY SUCCESSFUL"
    echo "=========================================="
    echo
    echo "Optimized services:"
    echo "  rc.inet2: inetd sshd bind"
    echo "  rc.M:     acpid cups crond atd postfix gpm"
    echo
    echo "smartd: unchanged (already asynchronous)"
    echo
}

status()
{
    echo "===== slackboot-optimize status ====="
    echo

    echo "rc.M:"
    grep -nE \
        'rc\.(acpid|cups|crond|atd|postfix|gpm) start' \
        "$RCM" 2>/dev/null

    echo

    echo "rc.inet2:"
    grep -nE \
        'rc\.(inetd|sshd|bind) start' \
        "$RCINET2" 2>/dev/null

    echo

    echo "Backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -1t "$BACKUP_DIR" 2>/dev/null
    else
        echo "  none"
    fi
}

backup()
{
    need_root

    mkdir -p "$BACKUP_DIR" ||
        die "Cannot create $BACKUP_DIR"

    stamp="$(date '+%Y%m%d-%H%M%S')"

    backup_file "$RCM" "$stamp"
    backup_file "$RCINET2" "$stamp"

    echo
    echo "Backup created:"
    echo "  $BACKUP_DIR/rc.M.$stamp"
    echo "  $BACKUP_DIR/rc.inet2.$stamp"
}

find_latest_pair()
{
    base_m="$(basename "$RCM")"
    base_i="$(basename "$RCINET2")"

    for latest_m in $(ls -1t "$BACKUP_DIR/$base_m".* 2>/dev/null); do
        stamp="${latest_m##*.}"

        if [ -f "$BACKUP_DIR/$base_i.$stamp" ]; then
            LATEST_STAMP="$stamp"
            return 0
        fi
    done

    return 1
}

rollback()
{
    need_root

    [ -d "$BACKUP_DIR" ] ||
        die "No backup directory found: $BACKUP_DIR"

    find_latest_pair ||
        die "No complete backup pair found."

    backup_m="$BACKUP_DIR/$(basename "$RCM").$LATEST_STAMP"
    backup_i="$BACKUP_DIR/$(basename "$RCINET2").$LATEST_STAMP"

    cp -p "$backup_m" "$RCM" ||
        die "Cannot restore $RCM"

    cp -p "$backup_i" "$RCINET2" ||
        die "Cannot restore $RCINET2"

    check_all

    echo
    echo "slackboot-optimize: ROLLBACK SUCCESSFUL"
}

usage()
{
    echo "Usage: $0 {check|status|backup|apply|rollback}"
}

case "$1" in
    check)
        check_all
        ;;
    status)
        status
        ;;
    backup)
        backup
        ;;
    apply)
        apply_changes
        ;;
    rollback)
        rollback
        ;;
    *)
        usage
        exit 1
        ;;
esac

exit 0
EOF

    chmod 755 "$SB" ||
        die "Cannot set permissions on $SB"

    check_file "$SB"

    echo "OK: $SB"
}

install_speeder()
{
    echo
    echo "Installing speeder-2.0..."

    cat > "$SP" <<'EOF'
#!/bin/sh

RCDIR=/etc/rc.d

case "$1" in
    --run)
        RUN=1
        ;;
    "")
        RUN=0
        ;;
    *)
        echo "Usage: $0 [--run]"
        exit 1
        ;;
esac

for script in "$RCDIR"/rc.*; do
    [ -f "$script" ] || continue
    [ -x "$script" ] || continue

    name=${script##*/}

    case "$name" in
        rc.0|rc.4|rc.6|rc.K|rc.M|rc.S|\
        rc.modules|rc.modules.local|\
        rc.udev|rc.syslog|rc.messagebus|rc.elogind|rc.sysvinit|\
        rc.inet1|rc.inet2|rc.inetd|rc.sshd|rc.bind|\
        rc.networkmanager|\
        rc.acpid|rc.atd|rc.crond|rc.cups|rc.gpm|rc.postfix|\
        rc.mysqld|rc.smartd|rc.cups-browsed|rc.mcelog|rc.ulogd|\
        rc.fuse|rc.fuse3|\
        rc.setterm|rc.numlock|\
        rc.local|rc.local_shutdown|\
        *.bak|*.orig|*.new|*.conf|*.before-*|*.pre-*|*~)
            echo "[SKIP] $name"
            continue
            ;;
    esac

    if [ "$name" = "rc.php-fpm" ] &&
       [ -r /var/run/php-fpm.pid ]; then

        pid=`cat /var/run/php-fpm.pid`

        if [ -n "$pid" ] &&
           ps -p "$pid" >/dev/null 2>&1; then
            echo "[SKIP] $name (already running: $pid)"
            continue
        fi
    fi

    if [ "$RUN" -eq 0 ]; then
        echo "[DRY ] $name"
    else
        echo "[RUN ] $name"
        /bin/sh "$script" start &
    fi
done

exit 0
EOF

    chmod 755 "$SP" ||
        die "Cannot set permissions on $SP"

    check_file "$SP"

    echo "OK: $SP"
}

integrate_rcm()
{
    echo
    echo "Checking rc.M integration..."

    [ -f "$RCM" ] ||
        die "Missing file: $RCM"

    #
    # Exact SPEЕDER hook.
    # The two lines identify the hook; the following fi is validated
    # by the rc.M syntax check.
    #
    if grep -Fqx 'if [ -x /usr/local/sbin/speeder-2.0 ]; then' "$RCM" &&
       grep -Fqx '  /usr/local/sbin/speeder-2.0' "$RCM"; then

        echo "SPEЕDER hook already present."
        return 0
    fi

    #
    # Refuse to guess if any old SPEЕDER reference exists.
    #
    if grep -Fq '/usr/local/sbin/speeder' "$RCM"; then
        echo "ERROR: existing SPEЕDER reference found in rc.M." >&2
        echo "Manual review required." >&2
        return 1
    fi

    #
    # Exact Slackware rc.local anchor.
    #
    backup="$(backup_rcm)"

    tmp="${RCM}.install-speeder.$$"

    awk '
        previous == 1 && $0 == "  /etc/rc.d/rc.local" {
            print
            previous=2
            next
        }

        previous == 2 && $0 == "fi" {
            print
            print ""
            print "# Start remaining selected rc files in background."
            print "if [ -x /usr/local/sbin/speeder-2.0 ]; then"
            print "  /usr/local/sbin/speeder-2.0"
            print "fi"
            found=1
            previous=3
            next
        }

        {
            print
        }

        $0 == "if [ -x /etc/rc.d/rc.local ]; then" {
            previous=1
        }

        END {
            if (found != 1)
                exit 2
        }
    ' "$RCM" > "$tmp"

    rc=$?

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmp"
        echo "ERROR: exact rc.local integration anchor not found." >&2
        echo "No change made to rc.M." >&2
        echo "Backup: $backup" >&2
        return 1
    fi

    old="${RCM}.install-speeder.old"

    cp -p "$RCM" "$old" ||
        {
            rm -f "$tmp"
            echo "ERROR: cannot create temporary preserved copy." >&2
            return 1
        }

    cat "$tmp" > "$old" ||
        {
            rm -f "$tmp" "$old"
            echo "ERROR: cannot prepare modified rc.M." >&2
            return 1
        }

    rm -f "$tmp"

    if ! sh -n "$old"; then
        rm -f "$old"
        echo "ERROR: modified rc.M failed syntax check." >&2
        echo "Original rc.M was NOT changed." >&2
        echo "Backup: $backup" >&2
        return 1
    fi

    mv "$old" "$RCM" ||
        {
            rm -f "$old"
            echo "ERROR: cannot install modified rc.M." >&2
            echo "Backup: $backup" >&2
            return 1
        }

    if ! sh -n "$RCM"; then
        echo "ERROR: final rc.M syntax check FAILED." >&2

        cp -p "$backup" "$RCM" ||
            die "CRITICAL: cannot restore rc.M from backup"

        echo "rc.M restored from backup."
        return 1
    fi

    echo "SPEЕDER hook installed."
    echo "Backup: $backup"

    return 0
}

main()
{
    need_root

    echo
    echo "=========================================="
    echo " install-speeder"
    echo " Slackware 15.0 Stable"
    echo "=========================================="
    echo
    echo "POSIX sh + KISS"
    echo

    check_file "$RCM"

    install_slackboot
    install_speeder

    integrate_rcm ||
        die "Installation stopped."

    echo
    echo "Checking installed components..."

    check_file "$SB"
    check_file "$SP"
    check_file "$RCM"

    echo
    echo "=========================================="
    echo " install-speeder: INSTALLATION SUCCESSFUL"
    echo "=========================================="
    echo
    echo "Installed:"
    echo "  $SB"
    echo "  $SP"
    echo
    echo "Integrated:"
    echo "  $RCM"
    echo
    echo "slackboot-optimize was NOT applied."
    echo "No rc.d executable bits were changed."
    echo "No rc.inet1/rc.inet2 changes were made."
    echo
}

main "$@"

exit 0

chmod 755 install-speeder
#su -
#./install-speeder
#/usr/local/sbin/slackboot-optimize apply
sleep 5
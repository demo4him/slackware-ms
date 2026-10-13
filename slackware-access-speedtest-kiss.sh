#!/bin/bash
#
# Slackware Mirror Speedtest - KISS
# Measures access/connect time and download speed for the two chosen sources.
# HTTPS certificate verification stays enabled. No system changes.
#

set -u
export LC_ALL=C

CONNECT_TIMEOUT=10
MAX_TIME=90
TEST_FILE="kernels/huge.s/bzImage"

RED='' GREEN='' YELLOW='' CYAN='' NC=''
if [[ -t 1 ]]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    CYAN=$'\033[36m'; NC=$'\033[0m'
fi

say() { printf '%b\n' "$*"; }
die() { say "${RED}ERROR:${NC} $*"; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."
[[ -r /etc/slackware-version ]] || die "Cannot read /etc/slackware-version."

VERSION=$(sed -nE 's/.*Slackware ([0-9]+(\.[0-9]+)?|current).*/\1/p' \
    /etc/slackware-version | head -n 1)
[[ -n "$VERSION" ]] || die "Could not detect Slackware version."

case "$(uname -m)" in
    x86_64) TREE="slackware64-${VERSION}" ;;
    i?86)   TREE="slackware-${VERSION}" ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
esac

# Four simple checks: each protocol is tested independently.
URLS=(
    "Slackware UK HTTPS|https://slackware.uk/slackware/${TREE}/${TEST_FILE}"
    "Slackware UK HTTP|http://slackware.uk/slackware/${TREE}/${TEST_FILE}"
    "Official HTTPS|https://ftp.slackware.com/pub/slackware/${TREE}/${TEST_FILE}"
    "Official HTTP|http://ftp.slackware.com/pub/slackware/${TREE}/${TEST_FILE}"
)

say "${CYAN}========================================${NC}"
say "${CYAN}       Slackware Access Speedtest${NC}"
say "${CYAN}========================================${NC}"
printf 'Slackware : %s\n' "$VERSION"
printf 'Test file : %s\n\n' "$TEST_FILE"
say "Measures connection setup time and download speed."
say "HTTPS certificate verification is enabled. No system changes."
say "${YELLOW}HTTP is diagnostic only; do not use it for package installation.${NC}"
printf '\n'

printf '%-24s %8s %9s %10s %10s\n' "ENDPOINT" "STATUS" "CONNECT" "TOTAL" "SPEED"
printf '%-24s %8s %9s %10s %10s\n' "------------------------" "--------" "---------" "----------" "----------"

success=0
for item in "${URLS[@]}"; do
    IFS='|' read -r label url <<< "$item"

    # curl reports:
    # time_connect = TCP connection time
    # time_appconnect = TLS handshake time (HTTPS; 0 for HTTP)
    # time_starttransfer = time to first byte
    # time_total = total transfer duration
    # speed_download = average bytes/second
    metrics=$(curl --location --silent --show-error --fail \
        --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
        --output /dev/null \
        --write-out '%{http_code}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}|%{size_download}|%{speed_download}' \
        "$url" 2>&1)
    rc=$?

    if (( rc != 0 )); then
        case "$rc" in
            6)  status="DNS-FAIL" ;;
            7)  status="CONN-FAIL" ;;
            28) status="TIMEOUT" ;;
            35|51|58|60|64|66|77|80|82|83|90|91) status="TLS-FAIL" ;;
            *)  status="FAIL($rc)" ;;
        esac
        printf '%-24s %8s %9s %10s %10s\n' "$label" "$status" "-" "-" "-"
        # Show one concise error line only.
        err=$(printf '%s\n' "$metrics" | grep -m1 -E 'curl: \([0-9]+\)')
        [[ -n "$err" ]] && printf '  %s\n' "$err"
        continue
    fi

    IFS='|' read -r http connect tls firstbyte total bytes speed <<< "$metrics"
    if [[ "$http" != "200" || -z "$speed" ]]; then
        printf '%-24s %8s %9s %10s %10s\n' "$label" "HTTP-$http" "-" "-" "-"
        continue
    fi

    success=1
    connect_ms=$(awk -v n="$connect" 'BEGIN{printf "%.0f ms",n*1000}')
    total_s=$(awk -v n="$total" 'BEGIN{printf "%.2f s",n}')
    speed_mbps=$(awk -v n="$speed" 'BEGIN{printf "%.2f Mbps",n*8/1000000}')
    printf '%-24s %8s %9s %10s %10s\n' "$label" "OK" "$connect_ms" "$total_s" "$speed_mbps"

    # Show first-byte and TLS timings only when relevant, without widening table.
    first_ms=$(awk -v n="$firstbyte" 'BEGIN{printf "%.0f",n*1000}')
    if [[ "$url" == https://* ]]; then
        tls_ms=$(awk -v n="$tls" 'BEGIN{printf "%.0f",n*1000}')
        printf '  TLS handshake: %s ms | first byte: %s ms | downloaded: %s bytes\n' \
            "$tls_ms" "$first_ms" "$bytes"
    else
        printf '  First byte: %s ms | downloaded: %s bytes\n' "$first_ms" "$bytes"
    fi
done

printf '\n'
if (( success )); then
    say "Done. Lower connection/first-byte times mean quicker access; higher Mbps means faster transfer."
    exit 0
fi

say "${RED}No endpoint completed successfully.${NC}"
exit 2

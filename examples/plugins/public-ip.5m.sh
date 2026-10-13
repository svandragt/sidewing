#!/bin/sh

# <xbar.title>IP</xbar.title>
# <xbar.version>1.2</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Shows the current public IPv4 address, plus IPv6 when available.</xbar.desc>
# <xbar.dependencies>curl</xbar.dependencies>
# <xbar.var>boolean(HIDE_IP_IN_BAR=true): Hide the IP address in the bar title.</xbar.var>

set -eu

if ! command -v curl >/dev/null 2>&1; then
    echo "IP: n/a"
    echo "---"
    echo "curl is required | color=red"
    exit 0
fi

ip="$(curl -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
ip6="$(curl -6 -fsS --max-time 4 https://api6.ipify.org 2>/dev/null || true)"

if [ -z "$ip" ]; then
    echo "IP: n/a"
    echo "---"
    echo "Unable to fetch public IP | color=red"
    exit 0
fi

case "${HIDE_IP_IN_BAR:-true}" in
    true|TRUE|1|yes|YES|on|ON)
        echo "IP"
        ;;
    *)
        echo "IP: $ip"
        ;;
esac

echo "---"
echo "$ip | length=32"
if [ -n "$ip6" ]; then
    echo "$ip6 | length=40"
fi

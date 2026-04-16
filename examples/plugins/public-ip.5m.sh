#!/bin/sh

# <xbar.title>Public IP</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>staba</xbar.author>
# <xbar.desc>Shows the current public IPv4 or IPv6 address.</xbar.desc>
# <xbar.dependencies>curl</xbar.dependencies>

set -eu

if ! command -v curl >/dev/null 2>&1; then
    echo "IP: n/a"
    echo "---"
    echo "curl is required | color=red"
    exit 0
fi

ip="$(curl -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"

if [ -z "$ip" ]; then
    echo "IP: n/a"
    echo "---"
    echo "Unable to fetch public IP | color=red"
    exit 0
fi

echo "IP: $ip"
echo "---"
echo "$ip | length=32"
echo "Refresh | refresh=true"

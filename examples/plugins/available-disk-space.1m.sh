#!/bin/sh

# <xbar.title>Available Disk Space</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>staba</xbar.author>
# <xbar.desc>Shows available disk space for the root filesystem.</xbar.desc>
# <xbar.dependencies>df</xbar.dependencies>

set -eu

if ! command -v df >/dev/null 2>&1; then
    echo "Disk: n/a"
    echo "---"
    echo "df is required | color=red"
    exit 0
fi

line="$(df -hP / | awk 'NR==2 { print $4 "|" $2 "|" $5 }')"

if [ -z "$line" ]; then
    echo "Disk: n/a"
    echo "---"
    echo "Unable to read disk usage | color=red"
    exit 0
fi

avail="$(printf '%s\n' "$line" | awk -F'|' '{print $1}')"
total="$(printf '%s\n' "$line" | awk -F'|' '{print $2}')"
used_pct="$(printf '%s\n' "$line" | awk -F'|' '{print $3}')"

echo "Disk: $avail"
echo "---"
echo "Available: $avail"
echo "Total: $total"
echo "Used: $used_pct"
echo "Refresh | refresh=true"

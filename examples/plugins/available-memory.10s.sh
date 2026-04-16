#!/bin/sh

# <xbar.title>Available Memory</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Shows available system memory from /proc/meminfo.</xbar.desc>
# <xbar.dependencies>awk</xbar.dependencies>

set -eu

if [ ! -r /proc/meminfo ]; then
    echo "Mem: n/a"
    echo "---"
    echo "/proc/meminfo unavailable | color=red"
    exit 0
fi

mem_avail_kb="$(awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo)"
mem_total_kb="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)"

if [ -z "${mem_avail_kb:-}" ] || [ -z "${mem_total_kb:-}" ]; then
    echo "Mem: n/a"
    echo "---"
    echo "Unable to parse /proc/meminfo | color=red"
    exit 0
fi

mem_avail_gib="$(awk -v kb="$mem_avail_kb" 'BEGIN { printf "%.1f", kb/1024/1024 }')"
mem_total_gib="$(awk -v kb="$mem_total_kb" 'BEGIN { printf "%.1f", kb/1024/1024 }')"
mem_pct="$(awk -v avail="$mem_avail_kb" -v total="$mem_total_kb" 'BEGIN { printf "%.0f", (avail/total)*100 }')"

echo "Mem: ${mem_avail_gib}G"
echo "---"
echo "Available: ${mem_avail_gib} GiB"
echo "Total: ${mem_total_gib} GiB"
echo "Available Percent: ${mem_pct}%"
echo "Refresh | refresh=true"

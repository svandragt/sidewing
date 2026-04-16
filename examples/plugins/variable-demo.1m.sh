#!/bin/sh

# <xbar.title>Variable Demo</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Demonstrates xbar-style plugin variables loaded from a sidecar JSON file.</xbar.desc>
# <xbar.dependencies>sh</xbar.dependencies>
# <xbar.var>string(VAR_NAME="Sidewing"): Display name.</xbar.var>
# <xbar.var>number(VAR_COUNT=3): Number of menu rows to show.</xbar.var>
# <xbar.var>boolean(VAR_VERBOSE=false): Show extra detail?</xbar.var>
# <xbar.var>select(VAR_STYLE="normal"): Style preset. [compact, normal, loud]</xbar.var>

set -eu

name="${VAR_NAME:-Sidewing}"
count="${VAR_COUNT:-3}"
verbose="${VAR_VERBOSE:-false}"
style="${VAR_STYLE:-normal}"

case "$style" in
    compact) label="$name" ;;
    loud) label="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')" ;;
    *) label="$name ($count)" ;;
esac

echo "$label"
echo "---"
echo "Name: $name"
echo "Count: $count"
echo "Verbose: $verbose"
echo "Style: $style"

if [ "$verbose" = "true" ]; then
    i=1
    while [ "$i" -le "$count" ] 2>/dev/null; do
        echo "Item $i for $name"
        i=$((i + 1))
    done
fi

echo "---"
echo "Refresh | refresh=true"

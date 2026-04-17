#!/bin/sh

# <xbar.title>IP</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Shows the current public IPv4 or IPv6 address.</xbar.desc>
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

if [ -z "$ip" ]; then
    echo "IP: n/a"
    echo "---"
    echo "Unable to fetch public IP | color=red"
    exit 0
fi

sidecar_path="${0}.vars.json"
show_flag_path="${0}.show-in-bar"
hide_ip_in_bar="${HIDE_IP_IN_BAR:-}"

if [ -z "$hide_ip_in_bar" ] && [ -f "$show_flag_path" ]; then
    hide_ip_in_bar=false
fi

if [ -z "$hide_ip_in_bar" ] && [ -f "$sidecar_path" ]; then
    hide_ip_in_bar="$(sed -n 's/.*"HIDE_IP_IN_BAR"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "$sidecar_path" | sed -n '1p')"
fi

if [ -z "$hide_ip_in_bar" ]; then
    hide_ip_in_bar=true
fi

case "$hide_ip_in_bar" in
    true|TRUE|1|yes|YES|on|ON)
        bar_label="IP"
        menu_status="hidden"
        next_label="Show IP In Bar"
        toggle_command="/usr/bin/touch"
        toggle_param1="$show_flag_path"
        ;;
    *)
        bar_label="IP: $ip"
        menu_status="shown"
        next_label="Hide IP In Bar"
        toggle_command="/bin/rm"
        toggle_param1="-f"
        toggle_param2="$show_flag_path"
        ;;
esac

echo "$bar_label"
echo "---"
echo "$ip | length=32"
if [ "${toggle_param2:-}" != "" ]; then
    echo "Bar display: $menu_status | shell=$toggle_command param1=$toggle_param1 param2=\"$toggle_param2\" refresh=true"
    echo "$next_label | shell=$toggle_command param1=$toggle_param1 param2=\"$toggle_param2\" refresh=true"
else
    echo "Bar display: $menu_status | shell=$toggle_command param1=\"$toggle_param1\" refresh=true"
    echo "$next_label | shell=$toggle_command param1=\"$toggle_param1\" refresh=true"
fi
echo "Refresh | refresh=true"

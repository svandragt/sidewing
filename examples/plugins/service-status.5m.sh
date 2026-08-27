#!/bin/sh

# <xbar.title>Service Status</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Rolls up the Statuspage health of GitHub, Zenhub, and Claude into one traffic light. Click to see each service.</xbar.desc>
# <xbar.dependencies>curl,jq</xbar.dependencies>

set -u

# name|status.json URL. Add a service by appending a line; the human-readable
# page is derived by stripping the /api/v2/status.json suffix. Any Atlassian
# Statuspage site works unchanged.
SERVICES="GitHub|https://www.githubstatus.com/api/v2/status.json
Zenhub|https://status.zenhub.com/api/v2/status.json
Claude|https://status.claude.com/api/v2/status.json"

# Statuspage indicator -> dot + severity rank. Unknown counts as a warning so a
# failed check never masquerades as green.
dot_for() {
    case "$1" in
        none) echo "🟢" ;;
        minor) echo "🟡" ;;
        major | critical) echo "🔴" ;;
        *) echo "⚪" ;;
    esac
}

sev_for() {
    case "$1" in
        none) echo 0 ;;
        minor) echo 1 ;;
        major) echo 2 ;;
        critical) echo 3 ;;
        *) echo 1 ;;
    esac
}

if [ "${1:-}" = "selftest" ]; then
    [ "$(dot_for none)" = "🟢" ] || { echo "FAIL none"; exit 1; }
    [ "$(dot_for critical)" = "🔴" ] || { echo "FAIL critical"; exit 1; }
    [ "$(dot_for garbage)" = "⚪" ] || { echo "FAIL unknown"; exit 1; }
    [ "$(sev_for none)" -lt "$(sev_for minor)" ] || { echo "FAIL rank"; exit 1; }
    [ "$(sev_for garbage)" -gt "$(sev_for none)" ] || { echo "FAIL unknown rank"; exit 1; }
    echo "ok"
    exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "⚪"
    echo "---"
    echo "curl and jq are required | color=red"
    exit 0
fi

worst=0
menu=""

# Iterate with a for loop, not `echo | while`: a piped while runs in a subshell
# and would drop worst/menu on exit.
old_ifs="$IFS"
IFS='
'
for line in $SERVICES; do
    IFS="$old_ifs"
    name="${line%%|*}"
    url="${line#*|}"
    [ -n "$name" ] || continue

    resp="$(curl -fsS --max-time 8 "$url" 2>/dev/null)" || resp=""
    if [ -n "$resp" ]; then
        indicator="$(printf '%s' "$resp" | jq -r '.status.indicator // "unknown"' 2>/dev/null)"
        desc="$(printf '%s' "$resp" | jq -r '.status.description // "Unknown"' 2>/dev/null)"
    else
        indicator="unknown"
        desc="Unreachable"
    fi

    dot="$(dot_for "$indicator")"
    sev="$(sev_for "$indicator")"
    [ "$sev" -gt "$worst" ] && worst="$sev"

    page="${url%/api/v2/status.json}/"
    menu="${menu}${dot} ${name} — ${desc} | href=${page}
"
    IFS='
'
done
IFS="$old_ifs"

case "$worst" in
    0) overall="🟢" ;;
    1) overall="🟡" ;;
    *) overall="🔴" ;;
esac

echo "$overall"
echo "---"
printf '%s' "$menu"
echo "---"
echo "Refresh | refresh=true"

#!/bin/sh

# <xbar.title>Service Status</xbar.title>
# <xbar.version>1.1</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Rolls up the health of several developer services into one traffic light. Click to see each service.</xbar.desc>
# <xbar.dependencies>curl,jq</xbar.dependencies>

set -u

# name|URL[|kind]. kind defaults to "statuspage" (Atlassian Statuspage v2, the
# /api/v2/status.json schema); "slack" handles Slack's own current-status API.
# Add a service by appending a line; for a Statuspage site the human-readable
# page is derived by stripping the /api/v2/status.json suffix.
SERVICES="GitHub|https://www.githubstatus.com/api/v2/status.json
Zenhub|https://status.zenhub.com/api/v2/status.json
Claude|https://status.claude.com/api/v2/status.json
Atlassian|https://status.atlassian.com/api/v2/status.json
Cloudflare|https://www.cloudflarestatus.com/api/v2/status.json
OpenAI|https://status.openai.com/api/v2/status.json
Slack|https://slack-status.com/api/v2.0.0/current|slack"

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

# Severity -> ascending sort rank so a single sort lists worst first (red 0,
# yellow/unknown 1, green 2) while names stay A-Z within a group.
order_for() {
    if [ "$1" -ge 2 ]; then
        echo 0
    elif [ "$1" -ge 1 ]; then
        echo 1
    else
        echo 2
    fi
}

if [ "${1:-}" = "selftest" ]; then
    [ "$(dot_for none)" = "🟢" ] || { echo "FAIL none"; exit 1; }
    [ "$(dot_for critical)" = "🔴" ] || { echo "FAIL critical"; exit 1; }
    [ "$(dot_for garbage)" = "⚪" ] || { echo "FAIL unknown"; exit 1; }
    [ "$(sev_for none)" -lt "$(sev_for minor)" ] || { echo "FAIL rank"; exit 1; }
    [ "$(sev_for garbage)" -gt "$(sev_for none)" ] || { echo "FAIL unknown rank"; exit 1; }
    [ "$(order_for "$(sev_for major)")" -lt "$(order_for "$(sev_for none)")" ] || { echo "FAIL order red<green"; exit 1; }
    [ "$(order_for "$(sev_for minor)")" -lt "$(order_for "$(sev_for none)")" ] || { echo "FAIL order yellow<green"; exit 1; }
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
rows=""

# Iterate with a for loop, not `echo | while`: a piped while runs in a subshell
# and would drop worst/menu on exit.
old_ifs="$IFS"
IFS='
'
for line in $SERVICES; do
    IFS="$old_ifs"
    name="${line%%|*}"
    rest="${line#*|}"
    url="${rest%%|*}"
    if [ "$rest" = "$url" ]; then
        kind="statuspage"
    else
        kind="${rest#*|}"
    fi
    [ -n "$name" ] || continue

    case "$kind" in
        slack)
            resp="$(curl -fsSL --max-time 8 "$url" 2>/dev/null)" || resp=""
            if [ -n "$resp" ]; then
                if [ "$(printf '%s' "$resp" | jq -r '.status // "unknown"' 2>/dev/null)" = "ok" ]; then
                    indicator="none"
                    desc="All Systems Operational"
                elif printf '%s' "$resp" | jq -e '.active_incidents[]? | select(.type == "outage")' >/dev/null 2>&1; then
                    indicator="major"
                    desc="$(printf '%s' "$resp" | jq -r '.active_incidents[0].title // "Service outage"' 2>/dev/null)"
                else
                    indicator="minor"
                    desc="$(printf '%s' "$resp" | jq -r '.active_incidents[0].title // "Active incident"' 2>/dev/null)"
                fi
            else
                indicator="unknown"
                desc="Unreachable"
            fi
            page="https://slack-status.com/"
            ;;
        *)
            resp="$(curl -fsS --max-time 8 "$url" 2>/dev/null)" || resp=""
            if [ -n "$resp" ]; then
                indicator="$(printf '%s' "$resp" | jq -r '.status.indicator // "unknown"' 2>/dev/null)"
                desc="$(printf '%s' "$resp" | jq -r '.status.description // "Unknown"' 2>/dev/null)"
            else
                indicator="unknown"
                desc="Unreachable"
            fi
            page="${url%/api/v2/status.json}/"
            ;;
    esac

    dot="$(dot_for "$indicator")"
    sev="$(sev_for "$indicator")"
    [ "$sev" -gt "$worst" ] && worst="$sev"

    # Tab-delimited sort keys (order, name) prefix each line; stripped before display.
    rows="${rows}$(order_for "$sev")	${name}	${dot} ${name} — ${desc} | href=${page}
"
    IFS='
'
done
IFS="$old_ifs"

menu="$(printf '%s' "$rows" | sort -t'	' -k1,1n -k2,2 | cut -f3-)"

case "$worst" in
    0) overall="🟢" ;;
    1) overall="🟡" ;;
    *) overall="🔴" ;;
esac

echo "$overall"
echo "---"
printf '%s\n' "$menu"
# Sidewing appends its own separator and Refresh action, so this plugin stops
# at the service list.

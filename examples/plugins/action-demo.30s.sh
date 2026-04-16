#!/bin/sh

# <xbar.title>Action Demo</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Demonstrates shell actions, ordered params, and refresh=true.</xbar.desc>
# <xbar.dependencies>touch, rm, date</xbar.dependencies>

set -eu

state_file="/tmp/sidewing-action-demo.flag"
stamp_file="/tmp/sidewing-action-demo.updated"

if [ -f "$state_file" ]; then
    status="on"
else
    status="off"
fi

last_updated="never"
if [ -f "$stamp_file" ]; then
    last_updated="$(cat "$stamp_file" 2>/dev/null || printf 'unknown')"
fi

echo "Action: $status"
echo "---"
echo "Status: $status"
echo "Last Updated: $last_updated"
echo "---"
echo "Turn On | shell=/usr/bin/touch param1=\"$state_file\" refresh=true"
echo "Turn Off | shell=/bin/rm param1=-f param2=\"$state_file\" refresh=true"
echo 'Stamp Update Time | shell=/bin/sh param1=-c param2="date '\''+%Y-%m-%d %H:%M:%S'\'' > $1" param3=sidewing-action-demo param4="'"$stamp_file"'" refresh=true'
echo "Open /tmp | shell=/usr/bin/xdg-open param1=/tmp"

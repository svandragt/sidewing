#!/bin/sh

# <xbar.title>Assigned GitHub PRs</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Shows the number of open pull requests assigned to the authenticated GitHub user.</xbar.desc>
# <xbar.dependencies>gh</xbar.dependencies>

set -eu

if ! command -v gh >/dev/null 2>&1; then
    echo "PRs: n/a"
    echo "---"
    echo "GitHub CLI (gh) is required | color=red"
    exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "PRs: n/a"
    echo "---"
    echo "Run gh auth login | color=red"
    exit 0
fi

count="$(
    gh search prs --state open --assignee @me --json number,repository --limit 100 \
        --jq 'map("\(.repository.nameWithOwner)#\(.number)") | unique | length' \
        2>/dev/null
)"

if [ -z "$count" ]; then
    echo "PRs: n/a"
    echo "---"
    echo "Unable to query GitHub PRs | color=red"
    exit 0
fi

echo "PRs: $count"
echo "---"
echo "Open assigned PRs: $count"
echo "Open GitHub PR dashboard | href=https://github.com/pulls/assigned"
echo "Refresh | refresh=true"

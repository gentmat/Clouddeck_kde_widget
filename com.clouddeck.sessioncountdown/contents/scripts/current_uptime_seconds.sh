#!/usr/bin/env bash
set -u

AWK="/usr/bin/awk"

uptime_seconds="$($AWK '{print int($1)}' /proc/uptime 2>/dev/null || true)"

if [ -z "${uptime_seconds:-}" ] || ! [[ "$uptime_seconds" =~ ^[0-9]+$ ]] || [ "$uptime_seconds" -lt 0 ]; then
    uptime_seconds=0
fi

printf '%s\n' "$uptime_seconds"

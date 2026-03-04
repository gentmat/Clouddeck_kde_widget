#!/usr/bin/env bash
set -u

DATE="/usr/bin/date"
AWK="/usr/bin/awk"

boot_epoch=""
while read -r key value _; do
    if [ "$key" = "btime" ]; then
        boot_epoch="$value"
        break
    fi
done </proc/stat

uptime_seconds="$($AWK '{print int($1)}' /proc/uptime 2>/dev/null || true)"

if [ -z "${boot_epoch:-}" ] || ! [[ "$boot_epoch" =~ ^[0-9]+$ ]] || [ "$boot_epoch" -le 0 ]; then
    boot_epoch="$($DATE +%s)"
fi

if [ -z "${uptime_seconds:-}" ] || ! [[ "$uptime_seconds" =~ ^[0-9]+$ ]] || [ "$uptime_seconds" -lt 0 ]; then
    uptime_seconds=0
fi

steady_now=$((boot_epoch + uptime_seconds))
if [ "$steady_now" -le 0 ]; then
    steady_now="$($DATE +%s)"
fi

printf '%s\n' "$steady_now"

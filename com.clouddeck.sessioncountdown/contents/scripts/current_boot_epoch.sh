#!/usr/bin/env bash
set -u

DATE="/usr/bin/date"

boot_epoch=""
while read -r key value _; do
    if [ "$key" = "btime" ]; then
        boot_epoch="$value"
        break
    fi
done </proc/stat

if [ -z "${boot_epoch:-}" ] || ! [[ "$boot_epoch" =~ ^[0-9]+$ ]] || [ "$boot_epoch" -le 0 ]; then
    boot_epoch="$("$DATE" +%s)"
fi

printf '%s\n' "$boot_epoch"

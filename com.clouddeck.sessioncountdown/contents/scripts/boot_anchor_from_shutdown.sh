#!/usr/bin/env bash
set -u

JOURNALCTL="/usr/bin/journalctl"
GREP="/usr/bin/grep"
TAC="/usr/bin/tac"
HEAD="/usr/bin/head"
AWK="/usr/bin/awk"
DATE="/usr/bin/date"

current_boot_epoch=""
while read -r key value _; do
    if [ "$key" = "btime" ]; then
        current_boot_epoch="$value"
        break
    fi
done </proc/stat

if [ -z "${current_boot_epoch:-}" ] || ! [[ "$current_boot_epoch" =~ ^[0-9]+$ ]] || [ "$current_boot_epoch" -le 0 ]; then
    current_boot_epoch="$("$DATE" +%s)"
fi

if [ ! -x "$JOURNALCTL" ]; then
    printf '%s\n' "$current_boot_epoch"
    exit 0
fi

reboot_chain=0
i=1

while [ "$i" -le 30 ]; do
    if ! "$JOURNALCTL" -b "-$i" -n 1 --no-pager >/dev/null 2>&1; then
        break
    fi

    mode="$("$JOURNALCTL" -b "-$i" -n 400 --no-pager -o cat | "$TAC" | "$AWK" '
        /^System is rebooting\.$/ { print "reboot"; exit }
        /^Reached target reboot.target - System Reboot\.$/ { print "reboot"; exit }
        /^Finished systemd-reboot.service - System Reboot\.$/ { print "reboot"; exit }
        /^System is powering down\.$/ { print "poweroff"; exit }
        /^Reached target poweroff.target - System Power Off\.$/ { print "poweroff"; exit }
        /^Finished systemd-poweroff.service - System Power Off\.$/ { print "poweroff"; exit }
    ')"

    if [ "$mode" = "reboot" ]; then
        reboot_chain="$i"
        i=$((i + 1))
        continue
    fi

    break
done

anchor_offset=$((0 - reboot_chain))
boot_epoch="$("$JOURNALCTL" -b "$anchor_offset" -o short-unix --no-pager | "$HEAD" -n 1 | "$AWK" '{print int($1)}')"

if [ -z "${boot_epoch:-}" ] || ! [[ "$boot_epoch" =~ ^[0-9]+$ ]] || [ "$boot_epoch" -le 0 ]; then
    boot_epoch="$current_boot_epoch"
fi

printf '%s\n' "$boot_epoch"

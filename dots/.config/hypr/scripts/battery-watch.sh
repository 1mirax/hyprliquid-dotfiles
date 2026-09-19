#!/usr/bin/env bash
# One notification when the battery crosses into "low", one more at
# "critical". Nothing else - no sound, no forced action.
#
# The thresholds are deliberately NOT ours: they are read from upower's
# config, which is where the rest of the desktop world reads them too, so
# there is no second copy of the numbers to drift out of sync. Change them in
# /etc/UPower/UPower.conf and this follows.
#
# Written with builtins only. The first version asked upower over dbus and
# cost 98 ms of CPU per check - 141 seconds a day to read two small numbers.
# Reading sysfs directly is a fork-free page read, and the whole script now
# spawns exactly one process, and only in the minute something is wrong:
# notify-send.
set -uo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/battery-watch.level"
CONF=/etc/UPower/UPower.conf

low=20 crit=5                        # upower's own defaults, if the file is gone
if [[ -r $CONF ]]; then
    while IFS='=' read -r key val; do
        case $key in
            PercentageLow)      low=${val%%.*}  ;;
            PercentageCritical) crit=${val%%.*} ;;
        esac
    done <"$CONF"
fi

shopt -s nullglob
for bat in /sys/class/power_supply/BAT*; do
    [[ -r $bat/capacity && -r $bat/status ]] || continue

    read -r pct    <"$bat/capacity"
    read -r status <"$bat/status"

    # Anything but discharging forgets what was already reported, so unplugging
    # a second time warns again instead of staying silent for the rest of the day.
    if [[ $status != Discharging ]]; then
        echo none >"$STATE"
        exit 0
    fi

    if   (( pct <= crit )); then level=critical
    elif (( pct <= low  )); then level=low
    else                         level=none
    fi

    last=none
    [[ -r $STATE ]] && read -r last <"$STATE"
    [[ $level == "$last" ]] && exit 0
    echo "$level" >"$STATE"

    # Whole minutes left, integer maths: µWh / µW * 60. Skipped rather than
    # guessed when the kernel reports no rate.
    left=
    if [[ -r $bat/energy_now && -r $bat/power_now ]]; then
        read -r e <"$bat/energy_now"
        read -r p <"$bat/power_now"
        (( p > 0 )) && left="$(( e * 60 / p )) min left. "
    fi

    case $level in
        critical)
            # urgency=critical is styled red in mako and never times out.
            notify-send -a battery -u critical "Battery critical — ${pct}%" \
                "${left}Plug in now."
            ;;
        low)
            notify-send -a battery -u normal "Battery low — ${pct}%" "${left}"
            ;;
    esac
    exit 0
done

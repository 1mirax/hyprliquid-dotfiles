#!/usr/bin/env bash
# One notification when the battery crosses into "low", one more at
# "critical". Nothing else - no sound, no forced action.
#
# The thresholds are deliberately NOT ours. upower publishes a warning level
# per battery, taken from /etc/UPower/UPower.conf (low at 20%, critical at 5%,
# action at 2%), and this reads that. So the numbers live in one place, the
# same place the rest of the desktop world reads them from, and a machine that
# ships different defaults is still correct.
#
# Polled from a timer rather than subscribed over dbus on purpose: a dbus
# listener is a process resident for the whole session, while this is three
# forks a minute and nothing in between.
set -uo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/battery-watch.level"

dev="$(upower -e 2>/dev/null | grep -m1 -E 'battery_|BAT')" || exit 0
[ -n "$dev" ] || exit 0          # no battery: a desktop, nothing to warn about

info="$(upower -i "$dev" 2>/dev/null)" || exit 0
field() { sed -n "s/^ *$1: *//p" <<<"$info" | head -1; }

state="$(field state)"
level="$(field warning-level)"
pct="$(field percentage)"
left="$(field 'time to empty')"

# Anything but discharging forgets what was already reported, so unplugging a
# second time warns again instead of staying silent for the rest of the day.
if [ "$state" != "discharging" ]; then
    echo none >"$STATE"
    exit 0
fi

last="$(cat "$STATE" 2>/dev/null || echo none)"
[ "$level" = "$last" ] && exit 0
echo "$level" >"$STATE"

case "$level" in
    critical|action)
        # urgency=critical is styled red in mako and never times out.
        notify-send -a battery -u critical "Battery critical — $pct" \
            "${left:+$left left. }Plug in now."
        ;;
    low)
        notify-send -a battery -u normal "Battery low — $pct" "${left:+$left left.}"
        ;;
esac

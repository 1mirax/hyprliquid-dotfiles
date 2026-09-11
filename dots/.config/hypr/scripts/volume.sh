#!/usr/bin/env bash
# Volume keys with an on-screen readout in mako.
#
# mako draws a progress fill behind a notification when it carries an
# "int:value" hint - progress-color is already set in mako/config, it just had
# nothing sending the hint. x-canonical-private-synchronous makes each press
# replace the previous popup instead of stacking a queue of them; mako honours
# that name and x-dunst-stack-tag, both found in its binary.
#
# The ceiling matches modules/keybinds.lua: wpctl has none of its own, so
# without -l a held key climbs past unity into software gain.
set -uo pipefail

SINK="@DEFAULT_AUDIO_SINK@"
SRC="@DEFAULT_AUDIO_SOURCE@"
STEP=5
CEIL=1.5

# "Volume: 0.60" or "Volume: 0.60 [MUTED]" -> "60 0" / "60 1"
read_node() {
    wpctl get-volume "$1" 2>/dev/null |
        awk '{ printf "%.0f %d", $2 * 100, ($0 ~ /MUTED/) }'
}

# value is clamped to 100 because the bar cannot draw past full, while the
# text keeps the real number - the ceiling here is 150.
notify() {
    local text="$1" pct="$2" fill=$pct
    [ "$fill" -gt 100 ] && fill=100
    notify-send -a volume -u low \
        -h string:x-canonical-private-synchronous:volume \
        -h "int:value:$fill" "$text"
}

case "${1:-}" in
    up)   wpctl set-volume -l "$CEIL" "$SINK" "${STEP}%+" ;;
    down) wpctl set-volume "$SINK" "${STEP}%-" ;;
    mute) wpctl set-mute "$SINK" toggle ;;
    mic)  wpctl set-mute "$SRC" toggle ;;
    *)    echo "usage: $(basename "$0") up|down|mute|mic" >&2; exit 1 ;;
esac

if [ "${1}" = "mic" ]; then
    read -r pct muted <<<"$(read_node "$SRC")"
    if [ "$muted" = 1 ]; then notify "󰍭  Microphone muted" 0
    else                      notify "󰍬  Microphone $pct%" "$pct"; fi
    exit 0
fi

read -r pct muted <<<"$(read_node "$SINK")"
if [ "$muted" = 1 ]; then
    notify "󰖁  Muted" 0
elif [ "$pct" -eq 0 ]; then
    notify "󰖁  $pct%" 0
elif [ "$pct" -lt 34 ]; then
    notify "󰕿  $pct%" "$pct"
elif [ "$pct" -lt 67 ]; then
    notify "󰖀  $pct%" "$pct"
else
    notify "󰕾  $pct%" "$pct"
fi

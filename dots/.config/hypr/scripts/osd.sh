#!/usr/bin/env bash
# Volume and brightness keys with an on-screen readout in mako.
#
# mako draws a progress fill behind a notification when it carries an
# "int:value" hint - progress-color is set in mako/config under [app-name=osd],
# and this is what feeds it. x-canonical-private-synchronous makes each press
# replace the previous popup instead of stacking a queue of them; mako honours
# that name and x-dunst-stack-tag, both found in its binary, neither in its man
# page.
#
# One script for both because the notification half is identical - only the
# thing being changed and the glyph differ.
set -uo pipefail

SINK="@DEFAULT_AUDIO_SINK@"
SRC="@DEFAULT_AUDIO_SOURCE@"
STEP=5
# wpctl has no ceiling of its own: without -l a held key climbs past unity into
# software gain. 1.5 is deliberate, see modules/keybinds.lua.
CEIL=1.5
# Lowest the backlight may go by key. See the note on the bright-down branch.
FLOOR=5

# value is clamped to 100 because a bar cannot draw past full, while the text
# keeps the real number - volume goes to 150.
notify() {
    local text="$1" pct="$2" fill=$pct
    [ "$fill" -gt 100 ] && fill=100
    notify-send -a osd -u low \
        -h string:x-canonical-private-synchronous:osd \
        -h "int:value:$fill" "$text"
}

# "Volume: 0.60" or "Volume: 0.60 [MUTED]" -> "60 0" / "60 1"
audio_state() {
    wpctl get-volume "$1" 2>/dev/null |
        awk '{ printf "%.0f %d", $2 * 100, ($0 ~ /MUTED/) }'
}

show_sink() {
    local pct muted
    read -r pct muted <<<"$(audio_state "$SINK")"
    if   [ "$muted" = 1 ];  then notify "󰖁  Muted" 0
    elif [ "$pct" -eq 0 ];  then notify "󰖁  $pct%" 0
    elif [ "$pct" -lt 34 ]; then notify "󰕿  $pct%" "$pct"
    elif [ "$pct" -lt 67 ]; then notify "󰖀  $pct%" "$pct"
    else                         notify "󰕾  $pct%" "$pct"; fi
}

show_source() {
    local pct muted
    read -r pct muted <<<"$(audio_state "$SRC")"
    if [ "$muted" = 1 ]; then notify "󰍭  Microphone muted" 0
    else                      notify "󰍬  Microphone $pct%" "$pct"; fi
}

show_backlight() {
    # brightnessctl -m prints device,class,current,percent,max - field 4 already
    # carries the percentage, so there is nothing to compute from raw values.
    local pct
    pct="$(brightnessctl -m 2>/dev/null | awk -F, '{ gsub(/%/, "", $4); print $4 }')"
    case "$pct" in ''|*[!0-9]*) pct=0 ;; esac
    if   [ "$pct" -lt 34 ]; then notify "󰃞  $pct%" "$pct"
    elif [ "$pct" -lt 67 ]; then notify "󰃟  $pct%" "$pct"
    else                         notify "󰃠  $pct%" "$pct"; fi
}

case "${1:-}" in
    vol-up)     wpctl set-volume -l "$CEIL" "$SINK" "${STEP}%+"; show_sink ;;
    vol-down)   wpctl set-volume "$SINK" "${STEP}%-";            show_sink ;;
    mute)       wpctl set-mute "$SINK" toggle;                    show_sink ;;
    mic)        wpctl set-mute "$SRC" toggle;                     show_source ;;
    bright-up)   brightnessctl -q set "${STEP}%+"; show_backlight ;;
    # The floor is enforced here rather than with brightnessctl's own -n, which
    # clamps the RAW value at 1 of 24242 on this panel - that reads as 0% and
    # is a black screen with no way to see the key that would undo it. A floor
    # has to be a percentage to mean anything.
    #
    # (-n also takes no separate argument: "-n 1" swallows the command and
    # brightnessctl prints its status instead of setting anything.)
    bright-down)
        cur="$(brightnessctl -m 2>/dev/null | awk -F, '{ gsub(/%/, "", $4); print $4 }')"
        case "$cur" in ''|*[!0-9]*) cur=100 ;; esac
        if [ "$cur" -le "$FLOOR" ]; then brightnessctl -q set "${FLOOR}%"
        else                             brightnessctl -q set "${STEP}%-"; fi
        show_backlight ;;
    *) echo "usage: $(basename "$0") vol-up|vol-down|mute|mic|bright-up|bright-down" >&2; exit 1 ;;
esac

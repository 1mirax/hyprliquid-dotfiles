#!/usr/bin/env bash
# Workspace buttons for waybar.
#
# waybar's own hyprland/workspaces module cannot switch workspaces on this
# setup: it hardcodes `dispatch workspace N`, which the Lua config wraps as
# `return hl.dispatch(workspace N)` - not valid Lua, so Hyprland rejects it
# with "')' expected near '2'". The module has no on-click option to override
# with, and upstream declined a compatibility mode, so the buttons are rebuilt
# here as five custom modules that dispatch the Lua form themselves.
#
#   workspace.sh state      refresh the cache (called from the Lua event)
#   workspace.sh <n>        print button n as JSON for waybar
#   workspace.sh focus <n>  switch to workspace n
#
# State goes through a cache file rather than each button calling hyprctl:
# five buttons would otherwise make ten IPC round trips per switch, which is
# long enough to see. modules/workspaces.lua refreshes the cache and then
# signals waybar, so the file is always written before anything reads it.
set -uo pipefail

CACHE="${XDG_RUNTIME_DIR:-/tmp}/hypr-workspaces"

# The temp file carries the pid: a click refreshes the cache itself and the
# compositor's event fires at the same moment, so two of these run
# concurrently. With one shared temp name the second mv finds nothing left to
# move and prints an error over waybar's stdout.
write_state() {
    local active occupied tmp="$CACHE.$$"
    active="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')"
    occupied="$(hyprctl workspaces -j 2>/dev/null | jq -r '.[] | select(.windows > 0) | .id' | tr '\n' ' ')"
    [ -n "$active" ] || { rm -f "$tmp"; return 1; }
    printf 'active=%s\noccupied=%s\n' "$active" "$occupied" >"$tmp" &&
        mv -f "$tmp" "$CACHE"
}

case "${1:-}" in
    state)
        write_state
        exit $?
        ;;
    focus)
        n="${2:?usage: workspace.sh focus <n>}"
        hyprctl dispatch "hl.dsp.focus({ workspace = \"$n\" })" >/dev/null 2>&1
        # Refresh immediately rather than waiting for the event, so the button
        # lights up on the same frame as the switch.
        write_state
        exit 0
        ;;
esac

n="${1:?usage: workspace.sh <n>|state|focus <n>}"

# Fall back to building the cache ourselves: at login waybar's modules run
# before the compositor has fired any workspace event.
[ -s "$CACHE" ] || write_state || { printf '{"text":"%s","class":["ws","empty"]}\n' "$n"; exit 0; }

active=""; occupied=""
# shellcheck disable=SC1090
while IFS='=' read -r k v; do
    case "$k" in active) active="$v" ;; occupied) occupied="$v" ;; esac
done <"$CACHE"

class="empty"
case " $occupied " in *" $n "*) class="occupied" ;; esac
[ "$n" = "$active" ] && class="active"

# Two classes: "ws" carries the shared look so the stylesheet does not have to
# name all five modules in every rule, the second carries the state.
printf '{"text":"%s","class":["ws","%s"]}\n' "$n" "$class"

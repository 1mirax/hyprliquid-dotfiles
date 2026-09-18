#!/usr/bin/env bash
# Session actions in fuzzel, on the laptop's power button.
#
# The power button is normally owned by logind, which acts on it directly -
# press and the machine goes down, no menu, no confirmation. A drop-in from
# .config/power/install.sh sets HandlePowerKey=ignore so the key arrives here
# as XF86PowerOff instead, and keybinds.lua hands it to this script.
#
# Every action is a one-liner; the menu exists to make the choice deliberate,
# which is the whole point of intercepting a button that used to cut power on
# its own.
set -uo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-power-menu.pid"

# Press again to dismiss, same as the bluetooth and audio menus. Without this
# the button toggles nothing: a second press just opens a second menu behind
# the first.
if [ -r "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -TERM "$(cat "$PIDFILE")"; exit 0
fi

# label<TAB>action. The tab keeps the label free of the action's syntax, and
# --accept-nth prints only the second field.
ROWS=$(printf '%s\n' \
    "󰌾  Lock	lock" \
    "󰤄  Suspend	suspend" \
    "󰗽  Log out	logout" \
    "󰜉  Reboot	reboot" \
    "󰐥  Shut down	poweroff")

choice="$(printf '%s\n' "$ROWS" |
    fuzzel --dmenu --namespace cheatsheet --prompt "power  " \
           --with-nth 1 --accept-nth 2 --lines 5 --width 26 &
    p=$!; echo "$p" >"$PIDFILE"; wait "$p"; rm -f "$PIDFILE")"

[ -n "$choice" ] || exit 0

case "$choice" in
    lock)
        # loginctl rather than hyprlock directly: hypridle already locks
        # through the same call, so both paths end up in one place, and a
        # session with no locker configured simply does nothing instead of
        # failing with a missing binary.
        loginctl lock-session
        ;;
    suspend)
        # Lock first, then suspend. Without this the screen comes back up
        # unlocked for as long as it takes hyprlock to start, and on resume
        # that is long enough to read.
        loginctl lock-session
        systemctl suspend
        ;;
    logout)
        # Under uwsm the session is a systemd unit, and stopping it is what
        # brings the whole graphical target down cleanly - killing Hyprland
        # directly leaves the user units running. UWSM_FINALIZE_VARNAMES is
        # the same marker modules/autostart.lua tests for.
        if [ -n "${UWSM_FINALIZE_VARNAMES:-}" ] && command -v uwsm >/dev/null; then
            uwsm stop
        else
            hyprctl dispatch 'hl.dsp.exit()'
        fi
        ;;
    reboot)   systemctl reboot ;;
    poweroff) systemctl poweroff ;;
esac

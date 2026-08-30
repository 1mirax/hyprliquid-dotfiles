#!/usr/bin/env bash
# Bluetooth picker: bzmenu driven through fuzzel.
#
# Wrapped in a script for two reasons: the keybind and waybar's on-click share
# one definition instead of two copies of a long quoted command, and waybar
# never sees bzmenu's {hint} placeholder - waybar substitutes {...} fields in
# on-click strings and would mangle it.
#
# bzmenu talks to BlueZ over D-Bus rather than scraping bluetoothctl output,
# which is why it can report scan progress and reopen itself when the scan ends.
exec bzmenu -l custom \
    --launcher-command "fuzzel --dmenu --namespace cheatsheet --width 46 --lines 12 --placeholder '{hint}'" \
    --interactive \
    --scan-duration 8

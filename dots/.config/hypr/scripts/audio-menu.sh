#!/usr/bin/env bash
# Audio picker: pwmenu driven through fuzzel.
#
# Same wrapper pattern as bluetooth-menu.sh - one definition shared by the
# keybind and waybar's on-click-right, and waybar never sees pwmenu's {hint}
# placeholder, which it would try to substitute as one of its own fields.
#
# pwmenu speaks to PipeWire directly, so it lists real graph nodes: outputs,
# inputs, and the streams of individual applications.
exec pwmenu -l custom \
    --launcher-command "fuzzel --dmenu --namespace cheatsheet --width 46 --lines 12 --placeholder '{hint}'" \
    --interactive

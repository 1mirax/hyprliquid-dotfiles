#!/usr/bin/env bash
# Audio device profiles in fuzzel.
#
# pwmenu covers devices and streams but not profiles, and pavucontrol - the
# usual way to reach them - is deliberately not installed. This fills that gap.
#
# The profile is what decides, on a Bluetooth headset, whether you get stereo
# with a dead microphone (A2DP) or a working microphone with telephone-grade
# sound (HSP/HFP). Classic Bluetooth cannot do both at once, so a call forces
# the switch and it does not always switch back.
#
# Indices are read from the graph, never assumed: on this machine the built-in
# card numbers its profiles 0-22 while the AirPods use 131073 and up.
set -uo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-audio-profile.pid"

if [ -r "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -TERM "$(cat "$PIDFILE")"; exit 0
fi

notify() { command -v notify-send >/dev/null && notify-send -a audio "$1" "${2-}"; }

# The reader is kept in a variable rather than inline so its own quoting is
# free of the shell's. A quoted heredoc means nothing here is expanded by bash.
read -r -d '' PW_READER <<'PY'
import sys, json, re

def short(d):
    # PipeWire spells bluez profiles out in full. These two patterns are its
    # own stable strings, so folding them keeps the menu readable; anything
    # unrecognised is shown exactly as reported.
    m = re.match(r"High Fidelity Playback \(A2DP Sink, codec (.+)\)", d)
    if m:
        return "A2DP · " + m.group(1)
    m = re.match(r"Headset Head Unit \(HSP/HFP, codec (.+)\)", d)
    if m:
        return "HFP · " + m.group(1) + "  (микрофон)"
    return d

try:
    objs = json.load(sys.stdin)
except Exception:
    sys.exit(1)

for o in objs:
    if not o.get("type", "").endswith("Device"):
        continue
    info = o.get("info", {})
    props = info.get("props", {})
    if props.get("media.class") != "Audio/Device":
        continue
    params = info.get("params", {})
    cur = params.get("Profile") or [{}]
    cur_i = cur[0].get("index")
    name = props.get("device.description") or props.get("device.name") or "?"
    for prof in params.get("EnumProfile", []):
        desc = prof.get("description", "")
        # "no" means the port is not plugged in - every unused HDMI output.
        if prof.get("available") == "no" or desc == "Off":
            continue
        mark = "*" if prof.get("index") == cur_i else " "
        print(mark + " " + short(desc) + "\t" + name + "\t" +
              str(o.get("id")) + ":" + str(prof.get("index")))
PY

list_profiles() {
    pw-dump 2>/dev/null | python3 -c "$PW_READER"
}

rows="$(list_profiles)"
[ -n "$rows" ] || { notify "Audio" "Не удалось прочитать граф PipeWire"; exit 1; }

# Column 1 shows the profile, 2 the device, 3 carries id:index and is returned.
choice="$(printf '%s\n' "$rows" |
    fuzzel --dmenu --namespace cheatsheet --prompt "profile  " \
           --with-nth '1  ·  2' --accept-nth 3 --lines 12 --width 52 &
    p=$!; echo "$p" >"$PIDFILE"; wait "$p"; rm -f "$PIDFILE")"
[ -n "$choice" ] || exit 0

dev="${choice%%:*}"; idx="${choice#*:}"
if wpctl set-profile "$dev" "$idx" 2>/dev/null; then
    label="$(printf '%s\n' "$rows" | grep -F "	$choice" | cut -f1 | sed 's/^..//')"
    notify "Audio" "${label:-профиль изменён}"
else
    notify "Audio" "Не удалось переключить профиль"
fi

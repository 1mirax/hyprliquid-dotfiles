#!/usr/bin/env bash
# Wi-Fi picker in fuzzel, driven by nmcli.
#
# Replaces `kitty -e nmtui` on the bar's network module: a terminal UI for
# picking a network is a whole window for a two-second decision, and it looks
# nothing like the rest of the setup.
#
# Toggling the radio, forgetting a network and the password prompt are all
# here, so nmtui is not needed for anything routine.
set -uo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-network-picker.pid"
FUZZEL=(fuzzel --dmenu --namespace cheatsheet --prompt "wifi  " --lines 12 --width 42)

# A second press closes the open picker instead of failing on fuzzel's lock.
if [ -r "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -TERM "$(cat "$PIDFILE")"
    exit 0
fi

notify() { command -v notify-send >/dev/null && notify-send -a network "$1" "${2-}"; }

pick() {
    "${FUZZEL[@]}" "$@" &
    local p=$!
    echo "$p" >"$PIDFILE"
    wait "$p"
    rm -f "$PIDFILE"
}

radio="$(nmcli -t -f WIFI radio 2>/dev/null)"
if [ "$radio" != "enabled" ]; then
    choice="$(printf 'Turn Wi-Fi on\n' | pick)"
    [ -n "$choice" ] && nmcli radio wifi on && notify "Wi-Fi" "Radio on"
    exit 0
fi

# rescan is best-effort: it fails while a scan is already in flight, and the
# cached list is fine in that case.
nmcli device wifi rescan >/dev/null 2>&1

current="$(nmcli -t -f ACTIVE,SSID device wifi list 2>/dev/null |
           awk -F: '$1=="yes"{print $2; exit}')"

# SIGNAL:SECURITY:SSID, strongest first, duplicates collapsed.
list="$(nmcli -t -f SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null |
  awk -F: '$3 != "" { if (!seen[$3]++) printf "%3d\t%s\t%s\n", $1, ($2=="" ? "open" : $2), $3 }' |
  sort -rn |
  while IFS=$'\t' read -r sig sec ssid; do
      mark=" "; [ "$ssid" = "$current" ] && mark="*"
      lock=" "; [ "$sec" != "open" ] && lock="#"
      printf '%s %s %3d%%  %s\n' "$mark" "$lock" "$sig" "$ssid"
  done)"

menu="$list"
[ -n "$current" ] && menu="$menu"$'\n'"  ---  disconnect from $current"
menu="$menu"$'\n'"  ---  turn Wi-Fi off"

choice="$(printf '%s\n' "$menu" | pick)"
[ -z "$choice" ] && exit 0

case "$choice" in
    *"turn Wi-Fi off")
        nmcli radio wifi off && notify "Wi-Fi" "Radio off"
        exit 0 ;;
    *"disconnect from "*)
        nmcli connection down id "${choice#*disconnect from }" >/dev/null &&
            notify "Wi-Fi" "Disconnected"
        exit 0 ;;
esac

# Strip the "* # 82%  " prefix back off to recover the SSID.
ssid="$(printf '%s' "$choice" | sed -E 's/^.{2} .{1} +[0-9]+%  //')"
[ -z "$ssid" ] && exit 0
[ "$ssid" = "$current" ] && exit 0

# A known network connects without asking; an unknown secured one needs a key.
if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
    nmcli connection up id "$ssid" >/dev/null 2>&1 &&
        notify "Wi-Fi" "Connected to $ssid" ||
        notify "Wi-Fi" "Could not connect to $ssid"
    exit 0
fi

if printf '%s' "$choice" | grep -q '^.\{2\} #'; then
    pass="$(: | fuzzel --dmenu --namespace cheatsheet --password \
                --prompt "$ssid  " --lines 0 --width 42)"
    [ -z "$pass" ] && exit 0
    nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 &&
        notify "Wi-Fi" "Connected to $ssid" ||
        notify "Wi-Fi" "Wrong password, or out of range"
else
    nmcli device wifi connect "$ssid" >/dev/null 2>&1 &&
        notify "Wi-Fi" "Connected to $ssid" ||
        notify "Wi-Fi" "Could not connect to $ssid"
fi

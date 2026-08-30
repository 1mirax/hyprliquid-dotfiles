#!/usr/bin/env bash
# Bluetooth picker in fuzzel, driven by bluetoothctl.
#
# One flat list: paired devices first, then whatever is nearby. A single press
# connects, disconnects or pairs, depending on what the device already is -
# there is no submenu to walk down for the common case.
#
# Every line carries a hidden second column holding the action and the MAC, and
# fuzzel is asked to display column 1 but return column 2 (--with-nth /
# --accept-nth). That keeps the MAC out of the visible text without having to
# parse the user's own selection back into an address, which breaks the moment
# two devices share a name.
set -uo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-bluetooth-picker.pid"

# BlueZ drops a device that is neither paired nor trusted a few seconds after
# discovery stops - measured here: all three still listed at +5s, none at +30s.
# So the scan is left running underneath the menu instead of being stopped
# before it opens, or the list would rot while it is on screen. SCAN_GATHER is
# how long we collect before showing anything; SCAN_WINDOW is how long the
# results stay valid afterwards.
SCAN_GATHER=6
SCAN_WINDOW=60
SCAN_PID=""

# A second press closes the open picker instead of failing on fuzzel's lock.
if [ -r "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -TERM "$(cat "$PIDFILE")"
    exit 0
fi

notify() { command -v notify-send >/dev/null && notify-send -a bluetooth "$1" "${2-}"; }

stop_scan() {
    [ -n "$SCAN_PID" ] && kill -TERM "$SCAN_PID" 2>/dev/null
    SCAN_PID=""
}

start_scan() {
    stop_scan
    # --timeout keeps bluetoothctl alive that long; without it the command
    # returns at once and discovery ends with it.
    bluetoothctl --timeout "$SCAN_WINDOW" scan on >/dev/null 2>&1 &
    SCAN_PID=$!
}

cleanup() { stop_scan; rm -f "$PIDFILE"; }
trap cleanup EXIT

if ! command -v bluetoothctl >/dev/null; then
    notify "Bluetooth" "bluez-utils is not installed"
    exit 1
fi

# stdin: "visible text<TAB>token" lines. stdout: the token of what was picked.
pick() {
    local prompt="$1" lines="${2:-12}"
    fuzzel --dmenu --namespace cheatsheet --prompt "$prompt" \
           --with-nth 1 --accept-nth 2 --lines "$lines" --width 46 &
    local p=$!
    echo "$p" >"$PIDFILE"
    wait "$p"
    rm -f "$PIDFILE"
}

# Devices whose name is just their own address are beacons and phones with
# address randomisation. They are never something you meant to connect to, and
# in a crowded room they are most of the list.
is_named() { [ "$2" != "${1//:/-}" ]; }

powered() { bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}'; }

# One call each, rather than `bluetoothctl info` per device - that spawns a
# process per line and is slow enough to notice once a scan has found 30 of them.
build_menu() {
    local paired connected mac name mark
    paired="$(bluetoothctl devices Paired 2>/dev/null | cut -d' ' -f2)"
    connected="$(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f2)"

    # Paired first, in bluetoothctl's own order.
    while read -r _ mac name; do
        [ -z "${mac:-}" ] && continue
        if printf '%s\n' "$connected" | grep -qxF "$mac"; then
            printf '  *  %s\tdisconnect:%s\n' "$name" "$mac"
        else
            printf '  +  %s\tconnect:%s\n' "$name" "$mac"
        fi
    done < <(bluetoothctl devices Paired 2>/dev/null)

    # Then anything else already in the cache from an earlier scan.
    while read -r _ mac name; do
        [ -z "${mac:-}" ] && continue
        printf '%s\n' "$paired" | grep -qxF "$mac" && continue
        is_named "$mac" "$name" || continue
        printf '     %s\tpair:%s\n' "$name" "$mac"
    done < <(bluetoothctl devices 2>/dev/null)
}

do_scan() {
    notify "Bluetooth" "Scanning" "Put the device into pairing mode now"
    start_scan
    sleep "$SCAN_GATHER"
}

do_pair() {
    local mac="$1" name="$2"
    # BlueZ pairs badly while discovery is still running, so the scan goes down
    # first - but only after the address is in hand, since stopping it is what
    # makes the device disappear from the list again.
    stop_scan
    notify "Bluetooth" "Pairing with $name"
    if bluetoothctl pair "$mac" >/dev/null 2>&1; then
        # Trusting is what lets the device reconnect on its own later; without
        # it every wake-up needs this menu again.
        bluetoothctl trust "$mac" >/dev/null 2>&1
        if bluetoothctl connect "$mac" >/dev/null 2>&1; then
            notify "Bluetooth" "Connected to $name"
        else
            notify "Bluetooth" "Paired with $name, but could not connect"
        fi
    else
        notify "Bluetooth" "Could not pair with $name" \
               "It may need to be put back into pairing mode"
    fi
}

name_of() { bluetoothctl devices 2>/dev/null | awk -v m="$1" '$2==m{$1="";$2="";sub(/^ +/,"");print;exit}'; }

while true; do
    if [ "$(powered)" != "yes" ]; then
        choice="$(printf 'Turn Bluetooth on\tpower-on\n' | pick "bt  " 1)"
        [ "$choice" = "power-on" ] || exit 0
        bluetoothctl power on >/dev/null && notify "Bluetooth" "On"
        sleep 0.5
        continue
    fi

    menu="$(build_menu)"
    [ -z "$menu" ] && menu="  (nothing paired or nearby)"$'\t'"noop"
    menu="$menu"$'\n'"  ···  scan for devices"$'\t'"scan"
    menu="$menu"$'\n'"  ···  forget a device"$'\t'"forget-menu"
    menu="$menu"$'\n'"  ···  turn Bluetooth off"$'\t'"power-off"

    choice="$(printf '%s\n' "$menu" | pick "bt  ")"
    [ -z "$choice" ] && exit 0

    case "$choice" in
        noop)      exit 0 ;;
        power-off) bluetoothctl power off >/dev/null && notify "Bluetooth" "Off"; exit 0 ;;
        scan)      do_scan; continue ;;

        forget-menu)
            list="$(bluetoothctl devices Paired 2>/dev/null |
                    while read -r _ mac name; do
                        [ -n "${mac:-}" ] && printf '  %s\t%s\n' "$name" "$mac"
                    done)"
            [ -z "$list" ] && { notify "Bluetooth" "Nothing is paired"; continue; }
            mac="$(printf '%s\n' "$list" | pick "forget  ")"
            [ -z "$mac" ] && continue
            name="$(name_of "$mac")"
            bluetoothctl remove "$mac" >/dev/null 2>&1 &&
                notify "Bluetooth" "Forgot ${name:-$mac}"
            continue ;;

        connect:*)
            mac="${choice#connect:}"; name="$(name_of "$mac")"
            stop_scan
            notify "Bluetooth" "Connecting to ${name:-$mac}"
            bluetoothctl connect "$mac" >/dev/null 2>&1 &&
                notify "Bluetooth" "Connected to ${name:-$mac}" ||
                notify "Bluetooth" "Could not connect to ${name:-$mac}"
            exit 0 ;;

        disconnect:*)
            mac="${choice#disconnect:}"; name="$(name_of "$mac")"
            bluetoothctl disconnect "$mac" >/dev/null 2>&1 &&
                notify "Bluetooth" "Disconnected from ${name:-$mac}"
            exit 0 ;;

        pair:*)
            mac="${choice#pair:}"; name="$(name_of "$mac")"
            do_pair "$mac" "${name:-$mac}"
            exit 0 ;;
    esac
done

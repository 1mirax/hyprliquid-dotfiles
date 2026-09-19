#!/usr/bin/env bash
# Keeps a copy of the compositor's log from the seconds after a resume.
#
# Hyprland logs under $XDG_RUNTIME_DIR, which is wiped on every boot. When the
# session hangs on wake the machine goes down by the power button, so the log
# of the hang never survives to be read. This runs as a system service right
# after resume - outside the session, so a hung session cannot stop it - and
# copies what the compositor has written into the user's state directory.
#
# Two snapshots: one immediately, one after half a minute. If the compositor
# hangs on wake, the difference between them is where it stopped.
#
# This is diagnostics, not part of the rice. Remove the service once the
# resume bug is understood.
set -uo pipefail

KEEP=20

snapshot() {
    local when="$1" log uid gid home dir
    for log in /run/user/*/hypr/*/hyprland.log; do
        [ -f "$log" ] || continue
        uid="$(stat -c %u "$log")"
        gid="$(stat -c %g "$log")"
        home="$(getent passwd "$uid" | cut -d: -f6)"
        [ -n "$home" ] && [ -d "$home" ] || continue
        dir="$home/.local/state/hypr-resume"
        install -d -o "$uid" -g "$gid" -m 0700 "$dir"
        install -o "$uid" -g "$gid" -m 0600 "$log" \
            "$dir/$(date +%Y%m%d-%H%M%S)-$when.log"
        # Oldest first, so everything past the newest KEEP files goes.
        ls -1t "$dir" 2>/dev/null | tail -n "+$((KEEP + 1))" | while read -r old; do
            rm -f -- "$dir/$old"
        done
    done
}

snapshot wake
sleep 30
snapshot wake+30

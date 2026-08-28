#!/usr/bin/env bash
# Wallpaper + colour scheme.
#
#   wallpaper.sh set <path>   apply and remember
#   wallpaper.sh pick         choose from WALLDIR with fuzzel (thumbnails)
#   wallpaper.sh random       random one from WALLDIR
#   wallpaper.sh restore      re-apply the remembered one (used at login)
#   wallpaper.sh current      print the remembered path
#
# hyprpaper ignores its own config file on this version, so the image goes in
# over IPC. The path lives in STATE and nowhere else: neither hyprland.lua nor
# the systemd unit hardcodes it any more, they both just call `restore`.
#
# Colours are deliberately NOT derived from the image: the glass stays neutral.
set -euo pipefail

WALLDIR="${WALLDIR:-$HOME/Pictures/wallpapers}"
STATE="$HOME/.config/hypr/wallpaper"

die() { echo "$*" >&2; exit 1; }

list() {
    find "$WALLDIR" -maxdepth 1 -type f \
         \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
         | sort
}

current() {
    if [ -s "$STATE" ] && [ -f "$(cat "$STATE")" ]; then
        cat "$STATE"
    else
        list | head -1
    fi
}

apply_wallpaper() {
    local img="$1" i m ok=0

    # At login hyprpaper's IPC is not up straight away.
    for i in $(seq 1 40); do
        hyprctl hyprpaper listloaded >/dev/null 2>&1 && break
        sleep 0.25
    done

    # Without unloading, hyprpaper keeps every image ever set in memory.
    hyprctl hyprpaper unload all >/dev/null 2>&1 || true
    hyprctl hyprpaper preload "$img" >/dev/null 2>&1 || true

    for m in $(hyprctl monitors -j | jq -r '.[].name'); do
        for i in $(seq 1 20); do
            if hyprctl hyprpaper wallpaper "$m,$img" >/dev/null 2>&1; then
                ok=1; break
            fi
            sleep 0.25
        done
    done
    [ "$ok" = 1 ] || die "hyprpaper did not accept the wallpaper"
}

# hyprlock cannot read the state file, so its background path is rewritten
# whenever the wallpaper changes - otherwise the lock screen keeps the old one.
sync_hyprlock() {
    local img="$1" conf="$HOME/.config/hypr/hyprlock.conf"
    [ -f "$conf" ] || return 0
    sed -i "s|^\( *path = \).*|\1$img|" "$conf"
}

set_wallpaper() {
    local img
    img="$(readlink -f "$1")"
    [ -f "$img" ] || die "no such file: $img"
    apply_wallpaper "$img"
    printf '%s\n' "$img" > "$STATE"
    sync_hyprlock "$img"
    echo "wallpaper: $img"
}

case "${1:-}" in
    set)
        [ $# -ge 2 ] || die "usage: $(basename "$0") set <path>"
        set_wallpaper "$2"
        ;;
    pick)
        # fuzzel's dmenu protocol accepts an icon after \0icon\x1f, and a plain
        # file path works there - so the menu shows real thumbnails.
        sel="$(list | while read -r f; do
                   printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
               done | fuzzel --dmenu --prompt='wallpaper ' || true)"
        [ -n "$sel" ] || exit 0
        set_wallpaper "$WALLDIR/$sel"
        ;;
    random)
        img="$(list | shuf -n1)"
        [ -n "$img" ] || die "no images in $WALLDIR"
        set_wallpaper "$img"
        ;;
    restore)
        img="$(current)"
        [ -n "$img" ] || die "no wallpaper found in $WALLDIR"
        apply_wallpaper "$img"
        # Also re-sync the lock screen. On a fresh install hyprlock.conf is
        # rendered from its template with whatever image install.sh found
        # first, which is not necessarily the one the state file names.
        sync_hyprlock "$img"
        ;;
    current) current ;;
    *)
        echo "usage: $(basename "$0") set <path>|pick|random|restore|current" >&2
        exit 1
        ;;
esac

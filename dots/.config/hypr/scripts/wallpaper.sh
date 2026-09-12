#!/usr/bin/env bash
# Wallpaper + colour scheme.
#
#   wallpaper.sh set <path>   apply and remember
#   wallpaper.sh pick         choose from WALLDIR with fuzzel (thumbnails)
#   wallpaper.sh random       random one from WALLDIR
#   wallpaper.sh restore      re-apply the remembered one (used at login)
#   wallpaper.sh current      print the remembered path
#   wallpaper.sh daemon       run swaybg in the foreground (for the unit)
#
# swaybg has no IPC: the process IS the wallpaper, and changing it means
# replacing the process. That is the whole reason it replaced hyprpaper, which
# held 32.7 MB resident against swaybg's 3.1 MB - measured on this machine,
# same image - and needed a retry loop against a socket that was not up yet at
# login. There is no socket here to wait for.
#
# -m fill is deliberate. The screen is 16:9 and photographs are usually 3:2, so
# anything that merely fits the image letterboxes it: four of the nine
# wallpapers here would show 150px bars. fill crops the overflow instead.
#
# The path lives in STATE and nowhere else - neither hyprland.lua nor the unit
# hardcodes it, they both just ask for the remembered one.
#
# Colours are deliberately NOT derived from the image: the glass stays neutral.
#
# Oversized images are still downscaled into a cache first, though swaybg frees
# the decode immediately and no longer needs protecting from it: decoding
# 5184x3456 costs 586 ms every time the wallpaper is applied, and the cache
# turns that into a file read. Keyed by source path, mtime and target size, so
# a new wallpaper pays once. Originals are never modified, and STATE always
# names the original.
set -euo pipefail

WALLDIR="${WALLDIR:-$HOME/Pictures/wallpapers}"
STATE="$HOME/.config/hypr/wallpaper"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/wallpapers"

die() { echo "$*" >&2; exit 1; }

# Largest monitor, since one image is shared by all of them.
screen_size() {
    hyprctl monitors -j 2>/dev/null \
        | jq -r '.[] | "\(.width)x\(.height)"' \
        | sort -t x -k1,1n | tail -1
}

# Prints the path to hand to swaybg: the original when it is already small
# enough, otherwise a cached downscale. Any failure falls back to the original,
# so a missing ffmpeg or an odd file costs speed but never the wallpaper.
scaled() {
    local src="$1" scr w h sw sh key dst
    command -v ffmpeg  >/dev/null || { printf '%s\n' "$src"; return; }
    command -v ffprobe >/dev/null || { printf '%s\n' "$src"; return; }

    scr="$(screen_size)"; [ -n "$scr" ] || { printf '%s\n' "$src"; return; }
    sw="${scr%x*}"; sh="${scr#*x}"

    local dim
    dim="$(ffprobe -v error -select_streams v:0 \
                   -show_entries stream=width,height -of csv=p=0:s=x "$src" 2>/dev/null)"
    w="${dim%x*}"; h="${dim#*x}"
    case "$w$h" in *[!0-9]*|"") printf '%s\n' "$src"; return ;; esac

    # Already at or below the screen in both axes - nothing to gain.
    if [ "$w" -le "$sw" ] && [ "$h" -le "$sh" ]; then
        printf '%s\n' "$src"; return
    fi

    key="$(printf '%s' "$src" | sha256sum | cut -c1-16)"
    dst="$CACHE/$key-$(stat -c %Y "$src")-${sw}x${sh}.jpg"

    if [ ! -s "$dst" ]; then
        mkdir -p "$CACHE"
        # Drop earlier sizes of this same image before writing the new one.
        find "$CACHE" -maxdepth 1 -name "$key-*" -delete 2>/dev/null || true
        # force_original_aspect_ratio=increase covers the screen without
        # cropping, so swaybg's -m fill still decides the framing itself.
        if ! ffmpeg -v error -y -i "$src" \
                    -vf "scale=$sw:$sh:force_original_aspect_ratio=increase" \
                    -q:v 2 "$dst" 2>/dev/null; then
            rm -f "$dst"
            printf '%s\n' "$src"; return
        fi
    fi
    printf '%s\n' "$dst"
}

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

MODE=fill

# The unit runs this: swaybg in the foreground, so systemd owns it and can
# restart it. Nothing else should call it directly.
daemon() {
    local img
    img="$(scaled "$(current)")"
    exec swaybg -m "$MODE" -i "$img"
}

apply_wallpaper() {
    # Under systemd the unit owns the process, so ask it to restart rather than
    # spawning a second swaybg the unit knows nothing about.
    if systemctl --user list-unit-files wallpaper.service --no-legend 2>/dev/null \
        | grep -q wallpaper; then
        systemctl --user restart wallpaper.service
        return
    fi

    # Fallback for a session without the unit - the same one autostart.lua
    # covers. pkill -x matches on the process name, so it cannot match this
    # script the way `pkill -f` once matched the cheatsheet wrapper.
    pkill -x swaybg 2>/dev/null || true
    setsid "$0" daemon >/dev/null 2>&1 &
}

# hyprlock cannot read the state file, so its background path is rewritten
# whenever the wallpaper changes - otherwise the lock screen keeps the old one.
sync_hyprlock() {
    local img="$1" conf="$HOME/.config/hypr/hyprlock.conf"
    [ -f "$conf" ] || return 0
    sed -i "s|^\( *path = \).*|\1$img|" "$conf"
}

set_wallpaper() {
    local img use
    img="$(readlink -f "$1")"
    [ -f "$img" ] || die "no such file: $img"
    use="$(scaled "$img")"
    apply_wallpaper
    # STATE keeps the original: the cache is an implementation detail, and a
    # different monitor later needs a different downscale of the same source.
    printf '%s\n' "$img" > "$STATE"
    sync_hyprlock "$use"
    echo "wallpaper: $img"
    [ "$use" != "$img" ] && echo "   scaled: $use"
    return 0
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
        use="$(scaled "$img")"
        apply_wallpaper
        # Also re-sync the lock screen. On a fresh install hyprlock.conf is
        # rendered from its template with whatever image install.sh found
        # first, which is not necessarily the one the state file names.
        sync_hyprlock "$use"
        ;;
    current) current ;;
    daemon)  daemon ;;
    *)
        echo "usage: $(basename "$0") set <path>|pick|random|restore|current|daemon" >&2
        exit 1
        ;;
esac

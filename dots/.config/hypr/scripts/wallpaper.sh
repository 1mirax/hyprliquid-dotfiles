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
#
# Images larger than the screen are downscaled into a cache before being handed
# over. hyprpaper decodes the whole source into memory before it scales, so a
# 5184x3456 photo costs ~68 MB of RSS and a visible pause on every switch, all
# to fill 1920x1080. The cache is keyed by source path, mtime and target size,
# so a new wallpaper pays for this once. Originals are never modified, and
# STATE always names the original.
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

# Prints the path to hand to hyprpaper: the original when it is already small
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
        # cropping, so hyprpaper still decides the framing itself.
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

apply_wallpaper() {
    local img="$1" i m ok=0

    # At login hyprpaper's IPC is not up straight away.
    #
    # This must be a request hyprpaper actually implements. It used to ask for
    # `listloaded`, which this version answers with "invalid hyprpaper request"
    # - so the loop never broke early and spent its full 10 seconds on every
    # single wallpaper change, login or not. `listactive` is the one that
    # exists here.
    for i in $(seq 1 40); do
        hyprctl hyprpaper listactive >/dev/null 2>&1 && break
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
    local img use
    img="$(readlink -f "$1")"
    [ -f "$img" ] || die "no such file: $img"
    use="$(scaled "$img")"
    apply_wallpaper "$use"
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
        apply_wallpaper "$use"
        # Also re-sync the lock screen. On a fresh install hyprlock.conf is
        # rendered from its template with whatever image install.sh found
        # first, which is not necessarily the one the state file names.
        sync_hyprlock "$use"
        ;;
    current) current ;;
    *)
        echo "usage: $(basename "$0") set <path>|pick|random|restore|current" >&2
        exit 1
        ;;
esac

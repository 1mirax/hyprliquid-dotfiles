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
# swaybg is handed the original file, never a downscaled copy. There used to
# be a cache that pre-scaled anything larger than the screen; it was measured
# and removed. Same image, original against cached:
#
#   5184x3456 (18 MP)   3.1 MB resident, 1.08 s of CPU
#   1920x1280 cached    3.3 MB resident, 0.41 s of CPU
#   3840x2160 (8 MP)    3.3 MB resident, 0.44 s of CPU
#   1920x1080 cached    3.3 MB resident, 0.43 s of CPU
#
# Resident memory is identical - swaybg frees the decode once it has drawn,
# and what stays is a buffer the size of the screen whatever it was built
# from. The only gain was CPU at start, and only past roughly ten megapixels:
# at 4K it saved nothing measurable. Two thirds of a second once per login,
# against a cache directory, an ffmpeg dependency for it, and forty lines of
# bookkeeping that had to stay correct.
set -euo pipefail

WALLDIR="${WALLDIR:-$HOME/Pictures/wallpapers}"
STATE="$HOME/.config/hypr/wallpaper"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/wallpapers/thumbs"

die() { echo "$*" >&2; exit 1; }

# Prints a PNG thumbnail path for the menu, or nothing when one cannot be made.
#
# fuzzel draws PNG and SVG only - it links libpng and libresvg and has no JPEG
# decoder at all - so handing it a .jpg produces a row with no image and no
# error. Every wallpaper here is a JPEG, which is why the picker showed plain
# text for as long as it existed.
#
# 128px on the long edge: the menu draws them far smaller, and the whole set
# costs a few hundred kilobytes. Keyed by path and mtime, so replacing an
# image regenerates exactly one file.
thumb() {
    local src="$1" key dst
    command -v ffmpeg >/dev/null || return 0

    key="$(printf '%s' "$src" | sha256sum | cut -c1-16)"
    dst="$THUMBS/$key-$(stat -c %Y "$src" 2>/dev/null).png"
    [ -s "$dst" ] && { printf '%s\n' "$dst"; return 0; }

    mkdir -p "$THUMBS"
    find "$THUMBS" -maxdepth 1 -name "$key-*" -delete 2>/dev/null || true
    if ffmpeg -v error -y -i "$src" \
              -vf "scale='min(128,iw)':'min(128,ih)':force_original_aspect_ratio=decrease" \
              "$dst" 2>/dev/null; then
        printf '%s\n' "$dst"
    else
        rm -f "$dst"
    fi
}

list() {
    # 2>/dev/null: on a machine where no wallpaper has been put in place yet
    # the directory simply does not exist, and that is not an error worth
    # printing on every login.
    # `|| true` matters as much as the redirect: with `set -o pipefail` a
    # failing find makes the whole pipeline fail, and under `set -e` that kills
    # the script before the caller can check for an empty result.
    { find "$WALLDIR" -maxdepth 1 -type f \
           \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
           2>/dev/null || true; } | sort
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
    local img src
    src="$(current)"
    # A fresh install has no wallpaper yet. Passing an empty -i makes swaybg
    # exit non-zero, and with Restart=on-failure the unit would then flap every
    # two seconds for as long as the directory stays empty. A solid fill in the
    # palette background is a legitimate wallpaper, so the session comes up
    # looking deliberate and the unit stays up until an image is chosen.
    if [ -z "$src" ]; then
        echo "no image in $WALLDIR - falling back to a solid background" >&2
        exec swaybg -c "#14141a"
    fi
    exec swaybg -m "$MODE" -i "$src"
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
    local img
    img="$(readlink -f "$1")"
    [ -f "$img" ] || die "no such file: $img"
    apply_wallpaper
    printf '%s\n' "$img" > "$STATE"
    sync_hyprlock "$img"
    echo "wallpaper: $img"
    return 0
}

case "${1:-}" in
    set)
        [ $# -ge 2 ] || die "usage: $(basename "$0") set <path>"
        set_wallpaper "$2"
        ;;
    pick)
        # fuzzel's dmenu protocol accepts an icon after \0icon\x1f, and a plain
        # file path works there - but only for PNG and SVG, so what goes after
        # the separator is the cached thumbnail rather than the wallpaper.
        # A row whose thumbnail could not be made still lists, just without
        # the image.
        sel="$(list | while read -r f; do
                   printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$(thumb "$f")"
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
        apply_wallpaper
        # Also re-sync the lock screen. On a fresh install hyprlock.conf is
        # rendered from its template with whatever image install.sh found
        # first, which is not necessarily the one the state file names.
        sync_hyprlock "$img"
        ;;
    current) current ;;
    daemon)  daemon ;;
    *)
        echo "usage: $(basename "$0") set <path>|pick|random|restore|current|daemon" >&2
        exit 1
        ;;
esac

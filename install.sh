#!/usr/bin/env bash
#
# Install these dotfiles into $HOME.
#
#   ./install.sh            link everything, render templates, enable units
#   ./install.sh --dry-run  print what would happen, touch nothing
#   ./install.sh --unlink   undo the most recent run
#
# Everything under dots/ is symlinked rather than copied, so editing a config
# in ~/.config edits the file in this repository and `git status` shows it.
# Anything already in the way is moved aside with a timestamp, never deleted,
# and every such move is recorded so --unlink can put it back exactly.
#
# Packages are not installed here on purpose - see packages.txt and read it
# before running pacman on someone else's list.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS="$REPO/dots"
STAMP="$(date +%Y%m%d-%H%M%S)"
MANIFEST_DIR="$REPO/.install-state"
MANIFEST="$MANIFEST_DIR/$STAMP.tsv"
DRY=0
MODE=install

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        --unlink)  MODE=unlink ;;
        -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

say()   { printf '%s\n' "$*"; }
step()  { printf '\n== %s\n' "$*"; }
short() { printf '%s' "${1/#$HOME/\~}"; }

# Record one action so --unlink can reverse it. Columns: verb, target, backup.
record() {
    [ "$DRY" -eq 1 ] && return 0
    mkdir -p "$MANIFEST_DIR"
    printf '%s\t%s\t%s\n' "$1" "$2" "${3-}" >>"$MANIFEST"
}

link() {
    local src="$1" dst="$2" backup=""
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        say "   ok      $(short "$dst")"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup="$dst.bak-$STAMP"
        say "   backup  $(short "$dst")"
        [ "$DRY" -eq 1 ] || mv "$dst" "$backup"
    fi
    if [ "$DRY" -eq 1 ]; then
        say "   link    $(short "$dst")  (dry run)"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    record link "$dst" "$backup"
    say "   link    $(short "$dst")"
}

# Whole directories we own end to end. Linking the directory rather than each
# file means a new script appears in ~/.config without re-running this.
DIR_LINKS=(
    .config/hypr
    .config/waybar
    .config/kitty
    .config/fuzzel
    .config/mako
    .config/power
)

# Directories shared with packages or with the user's own files, so only the
# individual files we own are linked.
FILE_LINKS=(
    .config/starship.toml
    .config/fish/config.fish
    .config/fish/functions/fish_prompt.fish
    .config/fish/functions/fish_right_prompt.fish
    .config/gtk-3.0/settings.ini
    .config/gtk-3.0/gtk.css
    .config/gtk-4.0/settings.ini
    .config/gtk-4.0/gtk.css
    .config/systemd/user/cliphist-images.service
    .config/systemd/user/hyprpaper-wallpaper.service
    .config/systemd/user/polkit-gnome-agent.service
    .gtkrc-2.0
)

# systemd units that bring the session up. The first five ship with their own
# packages; the last three are ours. hyprpaper-wallpaper is WantedBy hyprpaper
# rather than the session target, to avoid an ordering cycle.
UNITS=(waybar mako hypridle hyprpaper cliphist
       cliphist-images polkit-gnome-agent hyprpaper-wallpaper)


render_hyprlock() {
    local tpl="$DOTS/.config/hypr/hyprlock.conf.in"
    local out="$DOTS/.config/hypr/hyprlock.conf"

    if [ -e "$out" ]; then
        say "   ok      already rendered; wallpaper.sh keeps it in sync"
        return
    fi
    # Prefer the wallpaper actually in use. That state file is ignored by git,
    # so it only exists when migrating an installation rather than cloning a
    # fresh one - in which case any image will do, and wallpaper.sh corrects
    # the lock screen on its next restore anyway.
    local wall state="$DOTS/.config/hypr/wallpaper"
    if [ -r "$state" ] && [ -e "$(head -1 "$state")" ]; then
        wall="$(head -1 "$state")"
    else
        wall="$(find "$HOME/Pictures/wallpapers" -maxdepth 1 -type f \
                 \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
                 2>/dev/null | sort | head -1)"
    fi
    if [ -z "$wall" ]; then
        say "   note    no wallpaper in ~/Pictures/wallpapers yet - hyprlock"
        say "           will fall back to its solid background until one is set"
    fi
    if [ "$DRY" -eq 1 ]; then
        say "   write   ~/.config/hypr/hyprlock.conf  (dry run)"
        return
    fi
    sed "s|@WALLPAPER@|${wall}|" "$tpl" >"$out"
    record render "$out" ""
    say "   write   ~/.config/hypr/hyprlock.conf"
}

enable_units() {
    for u in "${UNITS[@]}"; do
        if [ -z "$(systemctl --user list-unit-files "$u.service" --no-legend 2>/dev/null)" ]; then
            say "   skip    $u (unit not found - package missing?)"
            continue
        fi
        if [ "$DRY" -eq 1 ]; then
            say "   enable  $u  (dry run)"
            continue
        fi
        if systemctl --user is-enabled "$u.service" >/dev/null 2>&1; then
            say "   ok      $u already enabled"
            continue
        fi
        systemctl --user enable "$u.service" >/dev/null
        record enable "$u.service" ""
        say "   enable  $u"
    done
}

do_install() {
    step "Directories"
    for rel in "${DIR_LINKS[@]}"; do link "$DOTS/$rel" "$HOME/$rel"; done

    step "Individual files"
    for rel in "${FILE_LINKS[@]}"; do link "$DOTS/$rel" "$HOME/$rel"; done

    step "Desktop-entry overrides (hide clutter from the launcher)"
    for src in "$DOTS"/.local/share/applications/*.desktop; do
        link "$src" "$HOME/.local/share/applications/${src##*/}"
    done

    step "hyprlock background"
    render_hyprlock

    step "Small icon variants for apps that ship only huge ones"
    if python3 -c 'import gi' 2>/dev/null; then
        [ "$DRY" -eq 1 ] && say "   would run fix-oversized-icons.py" \
                         || python3 "$DOTS/.config/hypr/scripts/fix-oversized-icons.py"
    else
        say "   skip    needs python-gobject"
    fi

    step "User services"
    enable_units

    cat <<'EOF'

Done. Two things this script deliberately leaves to you:

  Packages   Read packages.txt first, then:
               sudo pacman -S --needed - < packages.txt
             and install `throttled` from the AUR.

  Power      The undervolt values are specific to one CPU sample, and too
             large a value panics the kernel. Read .config/power/throttled.conf
             before running:
               sudo bash ~/.config/power/install.sh

Log out and back in for the session units to take effect.
EOF
}

do_unlink() {
    local latest
    latest="$(ls -1 "$MANIFEST_DIR"/*.tsv 2>/dev/null | sort | tail -1 || true)"
    if [ -z "$latest" ]; then
        say "No install to undo: $MANIFEST_DIR holds no manifest."
        return 1
    fi
    step "Undoing $(basename "${latest%.tsv}")"
    # Reverse order, so nested paths come back before their parents.
    tac "$latest" | while IFS=$'\t' read -r verb target backup; do
        case "$verb" in
            link)
                [ -L "$target" ] && { [ "$DRY" -eq 1 ] || rm -f "$target"; }
                say "   unlink  $(short "$target")"
                if [ -n "$backup" ] && [ -e "$backup" ]; then
                    [ "$DRY" -eq 1 ] || mv "$backup" "$target"
                    say "   restore $(short "$target")"
                fi
                ;;
            render)
                [ "$DRY" -eq 1 ] || rm -f "$target"
                say "   remove  $(short "$target")"
                ;;
            enable)
                [ "$DRY" -eq 1 ] || systemctl --user disable "$target" >/dev/null 2>&1 || true
                say "   disable $target"
                ;;
        esac
    done
    [ "$DRY" -eq 1 ] || rm -f "$latest"
}

case "$MODE" in
    install) do_install ;;
    unlink)  do_unlink ;;
esac

#!/usr/bin/env python3
"""Keybind cheatsheet, rendered by fuzzel in dmenu mode.

This replaces a GTK layer-shell overlay. That version had to import gi, Gtk and
Gdk before it could draw anything, which cost ~750 ms measured with
python3 -X importtime, and keeping it resident to avoid paying that twice held
114 MB of RSS - while GtkLayerShell would not reliably re-map a hidden surface,
so it opened exactly once. None of those problems exist here: fuzzel is already
on disk, starts in about 50 ms, and exits on its own when it loses focus.

The list is read from `hyprctl binds -j`, so it cannot drift from the config.
Bindings are grouped by the part of their description before the colon, the
same "Category: Action" convention illogical-impulse uses. Everything with a
description is listed - the old version had to curate the rows to fit on
screen, but a searchable list has no such limit.

Selecting a row copies the key combo to the clipboard.
"""
import json
import os
import signal
import subprocess
import sys

PIDFILE = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr-cheatsheet.pid")

# Categories are listed in this order; anything unlisted follows, alphabetically.
CATEGORY_ORDER = [
    "Apps", "Window", "Focus", "Move window", "Workspace",
    "Resize", "Scratchpad", "Capture", "Clipboard",
    "Notifications", "Wallpaper", "Media", "Display", "Session",
]

MOD_BITS = [
    (64, "Super"), (8, "Alt"), (4, "Ctrl"), (1, "Shift"),
]

KEY_LABELS = {
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "Return": "Enter", "Print": "PrtSc", "Slash": "/",
    "XF86AudioMute": "Mute", "XF86AudioRaiseVolume": "Vol +",
    "XF86AudioLowerVolume": "Vol −", "XF86AudioMicMute": "Mic mute",
    "XF86AudioPlay": "Play", "XF86AudioNext": "Next",
    "XF86AudioPrev": "Prev", "XF86MonBrightnessUp": "Bright +",
    "XF86MonBrightnessDown": "Bright −",
}

# Monospace, so the padded columns actually line up. The launcher keeps Inter -
# this is a table, and a table wants a fixed advance width.
FONT = "JetBrainsMono Nerd Font:size=13.5"
SEP = "   "
MAX_LINES = 18


def toggle_off_if_open():
    """Close a list that is already up, and report that we handled it."""
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
    except (OSError, ValueError):
        return False
    try:
        os.kill(pid, signal.SIGTERM)
        return True
    except (ProcessLookupError, PermissionError):
        # Stale pidfile from a crash - ignore it and open normally.
        return False


def key_combo(bind):
    mods = [name for bit, name in MOD_BITS if bind["modmask"] & bit]
    key = bind.get("key") or ""
    key = KEY_LABELS.get(key, key)
    if len(key) == 1:
        key = key.upper()
    return " + ".join(mods + [key]) if key else " + ".join(mods)


def rows():
    """(category, action, combo) for every described bind, in display order."""
    raw = subprocess.run(["hyprctl", "binds", "-j"],
                         capture_output=True, text=True, check=True).stdout
    seen, out = set(), []
    for b in json.loads(raw):
        desc = (b.get("description") or "").strip()
        if not desc or desc in seen:
            continue
        seen.add(desc)
        category, _, action = desc.partition(":")
        out.append((category.strip(), action.strip() or category.strip(),
                    key_combo(b)))

    def order(row):
        try:
            return (CATEGORY_ORDER.index(row[0]), row[1])
        except ValueError:
            return (len(CATEGORY_ORDER), row[0] + row[1])

    return sorted(out, key=order)


def main():
    if toggle_off_if_open():
        return

    data = rows()
    if not data:
        print("no described keybinds found", file=sys.stderr)
        return 1

    combo_w = max(len(c) for _, _, c in data)
    cat_w = max(len(c) for c, _, _ in data)
    lines = [f"{combo:<{combo_w}}{SEP}{cat:<{cat_w}}{SEP}{action}"
             for cat, action, combo in data]
    width = max(len(line) for line in lines) + 2

    proc = subprocess.Popen(
        # Its own namespace, so the layer rule can dim the screen behind it
        # without doing the same to the launcher.
        ["fuzzel", "--dmenu", "--namespace", "cheatsheet",
         "--prompt", "keys  ", "--font", FONT,
         "--width", str(width), "--lines", str(min(MAX_LINES, len(lines))),
         "--no-icons", "--match-mode", "fzf"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    with open(PIDFILE, "w") as f:
        f.write(str(proc.pid))
    try:
        picked, _ = proc.communicate("\n".join(lines))
    finally:
        try:
            os.unlink(PIDFILE)
        except OSError:
            pass

    picked = picked.strip()
    if not picked:
        return 0

    combo = picked[:combo_w].strip()
    subprocess.run(["wl-copy", "--"], input=combo, text=True, check=False)
    subprocess.run(["notify-send", "Copied", combo], check=False)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main() or 0)
    except subprocess.CalledProcessError:
        print("hyprctl binds failed - is Hyprland running?", file=sys.stderr)
        sys.exit(1)

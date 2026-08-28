#!/usr/bin/env python3
"""Generate small icon variants for apps that ship only a huge PNG.

fuzzel renders icons at row height. When an application provides nothing but a
512x512 PNG and no SVG, every launcher open decodes and downscales the whole
thing: AmneziaVPN alone cost 34 ms of a 90 ms startup, measured with
`fuzzel --print-timing-info`.

The fix is a smaller copy under ~/.local/share/icons, which takes precedence
over /usr/share without touching packaged files. This script finds every such
application and regenerates those copies, so the optimisation survives a clean
install and picks up newly installed programs instead of being a manual step
someone has to remember.

Idempotent: run it as often as you like. Safe to run after any package update.
"""
import argparse
import glob
import os
import re
import sys

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf  # noqa: E402

# Sizes to emit. The launcher asks for roughly row height; 32 is the closest
# standard bucket, 48 is there so the icon still looks right if the row grows.
TARGET_SIZES = (32, 48)

# Anything this size or larger is worth shrinking. Below it the decode is
# already cheap enough that a copy would just be clutter.
TOO_BIG = 128

APP_DIRS = ["/usr/share/applications",
            os.path.expanduser("~/.local/share/applications")]
ICON_ROOTS = ["/usr/share/icons", "/usr/share/pixmaps",
              os.path.expanduser("~/.local/share/icons")]
OUT_ROOT = os.path.expanduser("~/.local/share/icons/hicolor")

SIZE_IN_PATH = re.compile(r"/(\d+)x\1/")


def wanted_icon_names():
    """Icon= values of every desktop entry that actually shows in a menu."""
    names = set()
    for d in APP_DIRS:
        for path in glob.glob(os.path.join(d, "*.desktop")):
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if re.search(r"^NoDisplay\s*=\s*true", text, re.M | re.I):
                continue
            m = re.search(r"^Icon\s*=\s*(.+)$", text, re.M)
            if m:
                names.add(m.group(1).strip())
    return names


def icon_files(names):
    """name -> [paths], for icons we could find anywhere on the system."""
    found = {}
    for root in ICON_ROOTS:
        for dirpath, _, files in os.walk(root):
            for fn in files:
                base, ext = os.path.splitext(fn)
                if base in names and ext.lower() in (".png", ".svg", ".xpm"):
                    found.setdefault(base, []).append(os.path.join(dirpath, fn))
    return found


def offenders(found):
    """Icons with no SVG and no raster below TOO_BIG - yield (name, source)."""
    for name, paths in sorted(found.items()):
        if any(p.endswith(".svg") for p in paths):
            continue
        # Ignore anything we generated ourselves on a previous run.
        originals = [p for p in paths if not p.startswith(OUT_ROOT)]
        if not originals:
            continue
        sized = []
        for p in originals:
            m = SIZE_IN_PATH.search(p)
            if m:
                sized.append((int(m.group(1)), p))
        if not sized:
            continue
        smallest = min(sized)
        if smallest[0] >= TOO_BIG:
            # Downscale from the largest available: more detail to work with.
            yield name, max(sized)[1]


def emit(name, source, dry_run):
    made = []
    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(source)
    except Exception as exc:                       # noqa: BLE001
        print(f"  ! {name}: cannot read {source}: {exc}", file=sys.stderr)
        return made
    for size in TARGET_SIZES:
        out_dir = os.path.join(OUT_ROOT, f"{size}x{size}", "apps")
        out = os.path.join(out_dir, f"{name}.png")
        if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(source):
            continue
        if dry_run:
            made.append(out)
            continue
        os.makedirs(out_dir, exist_ok=True)
        pixbuf.scale_simple(size, size, GdkPixbuf.InterpType.HYPER).savev(
            out, "png", [], [])
        made.append(out)
    return made


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("-n", "--dry-run", action="store_true",
                    help="report what would be generated, change nothing")
    args = ap.parse_args()

    found = icon_files(wanted_icon_names())
    total = 0
    for name, source in offenders(found):
        made = emit(name, source, args.dry_run)
        if made:
            total += len(made)
            verb = "would generate" if args.dry_run else "generated"
            print(f"{name}: {verb} {len(made)} size(s) from {source}")
        else:
            print(f"{name}: already up to date")
    if total == 0:
        print("nothing to do - every menu icon has a small variant or an SVG")
    return 0


if __name__ == "__main__":
    sys.exit(main())

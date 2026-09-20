#!/usr/bin/env bash
# Installs the greetd login screen.
#
#   sudo bash ~/.config/greetd/install.sh
#
# It deliberately does NOT enable greetd or disable whatever display manager
# is running. Switching the way you log in is a separate, reversible step, and
# the script prints it at the end rather than doing it behind your back.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DST=/etc/greetd

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must run as root:  sudo bash $0" >&2
    exit 1
fi

for bin in greetd tuigreet; do
    command -v "$bin" >/dev/null || {
        echo "missing: $bin - install greetd greetd-tuigreet first" >&2
        exit 1
    }
done

echo "==> Installing configuration"
install -d -m 0755 "$DST"
if [ -f "$DST/config.toml" ] && ! cmp -s "$SRC/config.toml" "$DST/config.toml"; then
    cp -a "$DST/config.toml" "$DST/config.toml.bak-$STAMP"
    echo "    backed up $DST/config.toml -> config.toml.bak-$STAMP"
fi
install -m 0644 "$SRC/config.toml" "$DST/config.toml"
echo "    installed $DST/config.toml"

# tuigreet reads its own file from a fixed path and takes no --config flag,
# so this one cannot live next to greetd's.
install -d -m 0755 /etc/tuigreet
if [ -f /etc/tuigreet/config.toml ] && ! cmp -s "$SRC/tuigreet.toml" /etc/tuigreet/config.toml; then
    cp -a /etc/tuigreet/config.toml "/etc/tuigreet/config.toml.bak-$STAMP"
    echo "    backed up /etc/tuigreet/config.toml -> config.toml.bak-$STAMP"
fi
install -m 0644 "$SRC/tuigreet.toml" /etc/tuigreet/config.toml
echo "    installed /etc/tuigreet/config.toml"

# Parsed by tuigreet itself rather than trusted: an unknown key here means a
# greeter that will not start, and a greeter that will not start means no way
# to log in. Better to find out now, while ly is still the display manager.
if tuigreet --dump-config >/dev/null 2>&1; then
    echo "    tuigreet parses it"
else
    echo "    WARNING: tuigreet refused to parse the config - do NOT enable greetd" >&2
    tuigreet --dump-config 2>&1 | grep -viE "^thread|^note:|panicked" | head -5 >&2
fi

# Leftovers from the gtkgreet attempt. Harmless, but a stylesheet and a
# wallpaper sitting in /etc for a greeter that is no longer installed is the
# kind of thing that confuses the next person reading this machine.
echo "==> Clearing the gtkgreet attempt"
removed=0
for stale in "$DST/gtkgreet.css" "$DST/background.jpg" "$DST/environments"; do
    if [ -e "$stale" ]; then
        rm -f "$stale"
        echo "    removed $stale"
        removed=1
    fi
done
[ "$removed" -eq 1 ] || echo "    nothing to clear"

cat <<'NEXT'

==> Done. greetd is configured but NOT enabled.

    Try it without committing to it - the running session stays untouched
    on VT 2:

      sudo systemctl start greetd      # takes VT 1 and switches to it
      Ctrl+Alt+F2                      # come back

    Stuck on a black screen or a greeter that does not answer? From any
    console, or from a shell in the running session:

      loginctl activate c1             # back to your session, no root needed

    Happy with it? Make the switch - note there is no --now on the first
    line, and that is deliberate: ly is the leader of the session you are
    sitting in, so stopping it logs you out on the spot. Disabling it only
    changes what happens at the next boot.

      sudo systemctl disable ly@tty2
      sudo systemctl enable greetd

    Back out, same rule:

      sudo systemctl disable greetd
      sudo systemctl enable ly@tty2

    If greetd fails at the next boot, VT 1 is where it would have been -
    switch to another console (Ctrl+Alt+Fn+F2 on this ThinkPad, Fn because
    the top row sends media keys) and logind will spawn a getty there.

NEXT

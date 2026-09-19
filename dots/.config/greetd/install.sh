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

    Happy with it? Make the switch:

      sudo systemctl disable --now ly@tty2
      sudo systemctl enable greetd

    Back out at any point:

      sudo systemctl disable --now greetd
      sudo systemctl enable --now ly@tty2

NEXT

#!/usr/bin/env bash
# Installs the power stack for this ThinkPad: TLP + throttled.
# Safe to re-run: existing /etc configs are backed up once, with a timestamp.
#
#   sudo bash ~/.config/power/install.sh
#
set -euo pipefail

# Resolve our own directory, so the script works from a clone in any
# location and no absolute path is baked in.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must run as root:  sudo bash $0" >&2
    exit 1
fi

echo "==> Installing packages"
pacman -S --needed --noconfirm tlp tlp-rdw throttled

backup_and_copy() {
    local src="$1" dst="$2"
    if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp -a "$dst" "$dst.bak-$STAMP"
        echo "    backed up $dst -> $dst.bak-$STAMP"
    fi
    install -m 0644 "$src" "$dst"
    echo "    installed $dst"
}

echo "==> Installing configs"
backup_and_copy "$SRC/tlp.conf" /etc/tlp.conf
backup_and_copy "$SRC/throttled.conf" /etc/throttled.conf

echo "==> Ensuring the msr module is available (throttled needs it)"
printf 'msr\n' > /etc/modules-load.d/msr.conf
modprobe msr || echo "    WARNING: modprobe msr failed - throttled will not work"

echo "==> Freeing rfkill for TLP"
# TLP manages radio devices itself; systemd-rfkill would fight it.
systemctl mask systemd-rfkill.service systemd-rfkill.socket 2>/dev/null || true

echo "==> Enabling services"
systemctl enable --now tlp.service
systemctl enable --now throttled.service

echo
echo "==> Status"
systemctl is-active tlp.service throttled.service || true
echo
echo "Done. Useful commands:"
echo "  sudo tlp-stat -s     # overview"
echo "  sudo tlp-stat -b     # battery + charge thresholds"
echo "  sudo tlp-stat -p     # cpu / power policy"
echo "  sudo tlp fullcharge  # charge to 100% once, before travelling"

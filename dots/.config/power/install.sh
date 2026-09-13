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

# The undervolt in throttled.conf was found on ONE CPU sample by walking the
# voltage down until the kernel panicked and then backing off. Silicon varies
# between samples of the same model, let alone between models, and too large a
# value does not degrade gracefully - it panics or corrupts. So the values are
# only installed on the CPU they were tested on; anywhere else they are zeroed
# and throttled still does its useful half, the package power limits.
TUNED_CPU="i5-8265U"
THROTTLED_SRC="$SRC/throttled.conf"
if grep -q "$TUNED_CPU" /proc/cpuinfo; then
    echo "==> CPU is the $TUNED_CPU these values were tested on: undervolt kept"
else
    THROTTLED_SRC="$(mktemp)"
    sed -E 's/^(CORE|CACHE|GPU|UNCORE|ANALOGIO):[[:space:]]*-?[0-9]+/\1: 0/' \
        "$SRC/throttled.conf" >"$THROTTLED_SRC"
    cat <<WARN

    !!  This is not the $TUNED_CPU the undervolt was tested on:
    !!      $(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)
    !!  Installing throttled.conf with every undervolt set to 0. Power limits
    !!  still apply. To tune this machine, run undervolt-test.sh and walk the
    !!  value down yourself - do not copy a number from another laptop.

WARN
fi

echo "==> Installing configs"
backup_and_copy "$SRC/tlp.conf" /etc/tlp.conf
backup_and_copy "$THROTTLED_SRC" /etc/throttled.conf
[ "$THROTTLED_SRC" = "$SRC/throttled.conf" ] || rm -f "$THROTTLED_SRC"

echo "==> Ensuring the msr module is available (throttled needs it)"
printf 'msr\n' > /etc/modules-load.d/msr.conf
modprobe msr || echo "    WARNING: modprobe msr failed - throttled will not work"

echo "==> Leaving the Bluetooth adapter off at boot"
# One key, edited in place - not a whole-file copy. /etc/bluetooth/main.conf is
# BlueZ's own, it is long, and it gains options between releases; shipping a
# copy would freeze someone else's defaults at whatever they were the day this
# was written.
#
# This is not `systemctl disable bluetooth`. The service stays enabled, so
# bluetoothctl and the menu on Super+B keep working and can power the adapter
# up on demand. Disabling the service instead would mean nothing could turn
# Bluetooth on without first starting the service by hand.
#
# Separate from rfkill, which is what the F8 key toggles: AutoEnable decides
# whether a found controller is powered, rfkill whether it is blocked at all.
# The bar shows them as different states.
BT_CONF=/etc/bluetooth/main.conf
if [ -f "$BT_CONF" ]; then
    if grep -qE '^[[:space:]]*#?[[:space:]]*AutoEnable[[:space:]]*=' "$BT_CONF"; then
        sed -i -E 's/^[[:space:]]*#?[[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable=false/' "$BT_CONF"
        echo "    AutoEnable=false in $BT_CONF"
    else
        echo "    WARNING: no AutoEnable line in $BT_CONF - add it under [Policy] by hand"
    fi
else
    echo "    skip    $BT_CONF not present (bluez not installed?)"
fi

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

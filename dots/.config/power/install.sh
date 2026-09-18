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

# What this machine is decides how much of the stack applies. TLP is generic
# and runs anywhere; throttled writes Intel MSRs with package power limits
# chosen for a 15 W U-series ThinkPad, and its undervolt was found on one
# specific CPU sample. Neither travels.
VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
FAMILY="$(cat /sys/class/dmi/id/product_family 2>/dev/null || true)"
MODEL="$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)"
TUNED_CPU="i5-8265U"

IS_THINKPAD=0
case "$VENDOR $FAMILY" in
    LENOVO*ThinkPad*|*ThinkPad*) IS_THINKPAD=1 ;;
esac

echo "==> This machine"
echo "    $VENDOR $FAMILY"
echo "    $MODEL"

backup_and_copy() {
    local src="$1" dst="$2"
    if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp -a "$dst" "$dst.bak-$STAMP"
        echo "    backed up $dst -> $dst.bak-$STAMP"
    fi
    install -m 0644 "$src" "$dst"
    echo "    installed $dst"
}

echo "==> Installing packages"
if [ "$IS_THINKPAD" -eq 1 ]; then
    pacman -S --needed --noconfirm tlp tlp-rdw throttled
else
    pacman -S --needed --noconfirm tlp tlp-rdw
    echo "    throttled not installed: not a ThinkPad"
fi

echo "==> Installing configs"
backup_and_copy "$SRC/tlp.conf" /etc/tlp.conf

if [ "$IS_THINKPAD" -eq 0 ]; then
    cat <<'WARN'

    Skipping throttled entirely. Its power limits were picked for the 15 W
    package of a ThinkPad X390 Yoga, and raising a limit above what another
    machine was designed and cooled for is a thermal problem, not a tuning
    one. TLP alone still does governors, EPP, ASPM, runtime PM and radio
    power - the portable part of the stack.

WARN
else
    # The undervolt was found on ONE CPU sample by walking the voltage down
    # until the kernel panicked and then backing off. Silicon varies between
    # samples of the same model, let alone between models, and too large a
    # value does not degrade gracefully - it panics or corrupts. So the values
    # only install on the CPU they were tested on; on another ThinkPad they are
    # zeroed and throttled still does its useful half, the power limits.
    THROTTLED_SRC="$SRC/throttled.conf"
    if grep -q "$TUNED_CPU" /proc/cpuinfo; then
        echo "==> CPU is the $TUNED_CPU these values were tested on: undervolt kept"
    else
        THROTTLED_SRC="$(mktemp)"
        sed -E 's/^(CORE|CACHE|GPU|UNCORE|ANALOGIO):[[:space:]]*-?[0-9]+/\1: 0/' \
            "$SRC/throttled.conf" >"$THROTTLED_SRC"
        cat <<WARN

    !!  This is not the $TUNED_CPU the undervolt was tested on:
    !!      $MODEL
    !!  Installing throttled.conf with every undervolt set to 0. Power limits
    !!  still apply. To tune this machine, run undervolt-test.sh and walk the
    !!  value down yourself - do not copy a number from another laptop.

WARN
    fi
    backup_and_copy "$THROTTLED_SRC" /etc/throttled.conf
    [ "$THROTTLED_SRC" = "$SRC/throttled.conf" ] || rm -f "$THROTTLED_SRC"
fi

echo "==> Handing the power button to the session"
# A drop-in rather than an edit of logind.conf: the main file is systemd's own,
# it gains options between releases, and a drop-in leaves it untouched while
# overriding exactly one key.
install -d -m 0755 /etc/systemd/logind.conf.d
backup_and_copy "$SRC/logind-power-key.conf" /etc/systemd/logind.conf.d/10-power-key.conf
echo "    takes effect after a reboot, or: systemctl reload systemd-logind"

echo "==> Letting wheel suspend and reboot without a password"
# Under uwsm every process lives in user@1000.service rather than the session
# scope, so polkit may not resolve it to the active seat and refuses outright
# instead of prompting. hypridle's suspend at the idle timeout needs this too.
install -m 0644 "$SRC/49-wheel-power.rules" \
        /etc/polkit-1/rules.d/49-wheel-power.rules
echo "    installed /etc/polkit-1/rules.d/49-wheel-power.rules"

if [ "$IS_THINKPAD" -eq 1 ]; then
    echo "==> Ensuring the msr module is available (throttled needs it)"
    printf 'msr\n' > /etc/modules-load.d/msr.conf
    modprobe msr || echo "    WARNING: modprobe msr failed - throttled will not work"
fi

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
# An `[ ... ] && cmd` one-liner here would end the script under `set -e` the
# moment the test is false, taking the status report with it.
if [ "$IS_THINKPAD" -eq 1 ]; then
    systemctl enable --now throttled.service
fi

echo
echo "==> Status"
if [ "$IS_THINKPAD" -eq 1 ]; then
    systemctl is-active tlp.service throttled.service || true
else
    systemctl is-active tlp.service || true
fi
echo
echo "Done. Useful commands:"
echo "  sudo tlp-stat -s     # overview"
echo "  sudo tlp-stat -b     # battery + charge thresholds"
echo "  sudo tlp-stat -p     # cpu / power policy"
echo "  sudo tlp fullcharge  # charge to 100% once, before travelling"

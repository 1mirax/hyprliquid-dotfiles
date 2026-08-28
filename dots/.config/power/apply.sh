#!/usr/bin/env bash
# Applies the corrected throttled config (HWP_Mode key removed) and verifies
# that EPP now survives. Also retries the charge thresholds, which some
# ThinkPad ECs only accept while the charger is connected.
#
#   sudo bash ~/.config/power/apply.sh
#
set -euo pipefail

# Resolve our own directory, so the script works from a clone in any
# location and no absolute path is baked in.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo" >&2; exit 1; }

EPP=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
BAT=/sys/class/power_supply/BAT0
ON_AC=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 0)

echo "==> Installing throttled.conf without the HWP_Mode key"
install -m 0644 "$SRC/throttled.conf" /etc/throttled.conf
systemctl restart throttled.service
tlp start >/dev/null
sleep 3

# What counts as correct depends on the power source, per tlp.conf.
if [ "$ON_AC" = "1" ]; then
    WANT=balance_performance
else
    WANT=power
fi
echo "  EPP right after:        $(cat $EPP)   (expected: $WANT)"
echo "  waiting 12s to see if throttled writes it back..."
sleep 12
FINAL=$(cat $EPP)
echo "  EPP after settling:     $FINAL"
[ "$FINAL" = "$WANT" ] && echo "  => FIXED" || echo "  => still wrong, needs another look"

echo
echo "==> Charge thresholds"
if [ "$ON_AC" = "1" ]; then
    echo "  charger connected - writing stop first, then start"
    echo 80 > $BAT/charge_control_end_threshold 2>/dev/null || echo "  stop write rejected"
    sleep 1
    echo 75 > $BAT/charge_control_start_threshold 2>/dev/null || echo "  start write rejected"
    sleep 1
    echo "  start=$(cat $BAT/charge_control_start_threshold) stop=$(cat $BAT/charge_control_end_threshold)"
    if [ "$(cat $BAT/charge_control_end_threshold)" = "80" ]; then
        echo "  => thresholds work on AC; TLP will keep them from now on"
    else
        echo "  => EC still refuses a split threshold on this model"
    fi
else
    echo "  NOT on AC - the EC on this model appears to ignore the stop"
    echo "  threshold while discharging. Plug the charger in and re-run"
    echo "  this script to set them properly."
    echo "  current: start=$(cat $BAT/charge_control_start_threshold) stop=$(cat $BAT/charge_control_end_threshold)"
fi

echo
echo "==> Undervolt still in place?"
modprobe msr 2>/dev/null || true
python3 - <<'PY'
import struct
def read_plane(plane):
    with open("/dev/cpu/0/msr", "wb") as f:
        f.seek(0x150); f.write(struct.pack("<Q", 0x8000001000000000 | (plane << 40)))
    with open("/dev/cpu/0/msr", "rb") as f:
        f.seek(0x150); v = struct.unpack("<Q", f.read(8))[0]
    off = (v & 0xFFE00000) >> 21
    return round((off - 2048 if off > 1024 else off) / 1.024)
for n, i in (("CORE", 0), ("GPU", 1), ("CACHE", 2)):
    print(f"  {n:6} {read_plane(i):>5} mV")
PY

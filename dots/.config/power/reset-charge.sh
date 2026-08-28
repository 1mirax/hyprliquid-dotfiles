#!/usr/bin/env bash
# Removes the charge limit entirely: back to stock 0/100, no thresholds in TLP.
#
#   sudo bash ~/.config/power/reset-charge.sh
#
set -euo pipefail

# Resolve our own directory, so the script works from a clone in any
# location and no absolute path is baked in.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo" >&2; exit 1; }

BAT=/sys/class/power_supply/BAT0

install -m 0644 "$SRC/tlp.conf" /etc/tlp.conf

# Back to the driver defaults, and make sure charging is not inhibited.
echo auto > $BAT/charge_behaviour 2>/dev/null || true
echo 100 > $BAT/charge_control_end_threshold 2>/dev/null || true
echo 0   > $BAT/charge_control_start_threshold 2>/dev/null || true

tlp start >/dev/null
sleep 2

echo "start=$(cat $BAT/charge_control_start_threshold) stop=$(cat $BAT/charge_control_end_threshold)"
echo "behaviour: $(cat $BAT/charge_behaviour)"
echo "battery:   $(cat $BAT/capacity)% / $(cat $BAT/status)"
echo
echo "Charging to 100% again. Everything else (EPP, turbo, undervolt) unchanged."

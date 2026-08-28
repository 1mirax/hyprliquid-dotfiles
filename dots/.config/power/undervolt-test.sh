#!/usr/bin/env bash
# Does this CPU still accept an undervolt, or did microcode/BIOS lock it?
#
# Writes a deliberately tiny -25 mV offset to the core plane, reads it back,
# then resets to 0. -25 mV is far too small to destabilise anything; the point
# is only to see whether the write lands at all.
#
#   sudo bash ~/.config/power/undervolt-test.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Must run as root:  sudo bash $0" >&2
    exit 1
fi

modprobe msr 2>/dev/null || true
if [ ! -e /dev/cpu/0/msr ]; then
    echo "ERROR: /dev/cpu/0/msr missing - the msr module did not load." >&2
    exit 1
fi

python3 - <<'PY'
import struct

MSR = "/dev/cpu/0/msr"
PLANE = {"core": 0, "gpu": 1, "cache": 2, "uncore": 3, "analogio": 4}

def encode(plane, mv):
    off = int(round(mv * 1.024))
    off = 0xFFE00000 & ((off & 0xFFF) << 21)
    return 0x8000001100000000 | (plane << 40) | off

def read_cmd(plane):
    return 0x8000001000000000 | (plane << 40)

def decode(val):
    off = (val & 0xFFE00000) >> 21
    if off > 1024:
        off -= 2048
    return round(off / 1.024)

def write_msr(val):
    with open(MSR, "wb") as f:
        f.seek(0x150)
        f.write(struct.pack("<Q", val))

def read_msr():
    with open(MSR, "rb") as f:
        f.seek(0x150)
        return struct.unpack("<Q", f.read(8))[0]

TEST_MV = -25
try:
    write_msr(encode(PLANE["core"], TEST_MV))
    write_msr(read_cmd(PLANE["core"]))
    got = decode(read_msr())
except OSError as e:
    print(f"RESULT: BLOCKED - MSR write refused by the kernel/CPU ({e})")
    raise SystemExit(0)

print(f"wrote {TEST_MV} mV, read back {got} mV")
if got == TEST_MV:
    print("RESULT: SUPPORTED - undervolting still works on this machine.")
else:
    print("RESULT: BLOCKED - the write was silently ignored "
          "(microcode/BIOS Plundervolt mitigation).")

# Always reset to 0 so the test leaves nothing behind.
write_msr(encode(PLANE["core"], 0))
print("core plane reset to 0 mV")
PY

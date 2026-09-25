#!/usr/bin/env python3
"""Fold the desktop away as the lid comes down - the iPhone Duo effect.

Angle comes from the two accelerometers this ThinkPad already has, one in the
lid and one in the base: normalise both gravity vectors, take the angle
between them, and the hinge is 180 minus that. Checked against the hardware -
holding the lid at a real right angle reads 88.7 degrees between the planes -
so there is no fudge factor. The kernel also exposes a `hinge` IIO device that
would hand over the angle directly, but it reads zero until something powers
it on, and these two are live already.

The effect is a screen shader, and Hyprland gives a screen shader no way to
receive a value, so the fold has to be written into the source and the file
re-applied. A compile costs 13-135 ms, so the first version - which re-applied
on every small change - ran at about seven frames a second and stuttered
exactly as you would expect.

What makes it smooth is the `time` uniform, which restarts at zero on every
re-apply. So the shader is given a pair of numbers, where the fold is now and
where it is going, and eases between them on its own at full frame rate. The
daemon only recompiles when the lid has moved enough to be worth a new target,
and a re-target mid-flight starts from wherever the easing had got to.

Using `time` means damage tracking has to be off, which Hyprland warns is
expensive - so it is switched off only while the effect is on screen.
"""
import math
import os
import subprocess
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "fold.frag.in")
SHADER = os.path.join(HERE, "fold.frag")

LID, BASE = 1, 3
OPEN_AT = 90.0        # nothing happens while the lid is upright or further back
SHUT_AT = 15.0        # fully folded below this
RETARGET = 0.06       # fold change worth a recompile
EASE = 0.28           # must match EASE in the shader
RATE = 0.05           # how often the angle is read


def vector(dev):
    base = f"/sys/bus/iio/devices/iio:device{dev}"
    v = [int(open(f"{base}/in_accel_{a}_raw").read()) for a in "xyz"]
    m = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / m for c in v]


def hinge_angle():
    a, b = vector(LID), vector(BASE)
    dot = max(-1.0, min(1.0, sum(x * y for x, y in zip(a, b))))
    return 180.0 - math.degrees(math.acos(dot))


def fold_for(angle):
    if angle >= OPEN_AT:
        return 0.0
    if angle <= SHUT_AT:
        return 1.0
    return (OPEN_AT - angle) / (OPEN_AT - SHUT_AT)


def hypr(lua):
    subprocess.run(["hyprctl", "eval", lua], stdout=subprocess.DEVNULL)


def set_shader(path):
    hypr(f"hl.config({{ decoration = {{ screen_shader = '{path}' }} }})")


def damage_tracking(on):
    hypr(f"hl.config({{ debug = {{ damage_tracking = {2 if on else 0} }} }})")


class Fold:
    """Keeps track of what the shader is currently showing."""

    def __init__(self):
        self.frm = 0.0
        self.to = 0.0
        self.started = 0.0
        self.active = False

    def current(self):
        if not self.active:
            return 0.0
        t = min(1.0, (time.monotonic() - self.started) / EASE)
        t = t * t * (3.0 - 2.0 * t)
        return self.frm + (self.to - self.frm) * t

    def aim(self, target):
        self.frm = self.current()
        self.to = target
        self.started = time.monotonic()
        src = open(TEMPLATE).read()
        src = src.replace("__FROM__", f"{self.frm:.4f}").replace("__TO__", f"{target:.4f}")
        # Written whole and moved into place: re-applying a file that is still
        # being written is a compile error, and a failed compile leaves an
        # error banner on screen until the config is reloaded.
        tmp = SHADER + ".tmp"
        with open(tmp, "w") as fh:
            fh.write(src)
        os.replace(tmp, SHADER)
        if not self.active:
            damage_tracking(False)
            self.active = True
        set_shader(SHADER)

    def stop(self):
        if not self.active:
            return
        set_shader("")
        damage_tracking(True)
        self.active = False
        self.frm = self.to = 0.0


def main():
    fold = Fold()
    try:
        while True:
            target = fold_for(hinge_angle())
            if target == 0.0 and fold.active and fold.current() < 0.01:
                fold.stop()
            elif target > 0.0 or fold.active:
                if abs(target - fold.to) >= RETARGET:
                    fold.aim(target)
            time.sleep(RATE)
    except KeyboardInterrupt:
        fold.stop()


if __name__ == "__main__":
    main()

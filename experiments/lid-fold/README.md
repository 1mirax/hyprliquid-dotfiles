# Lid fold

The iPhone Duo effect on a ThinkPad: the desktop tilts away, blurs and dims as
the lid comes down. A prototype, kept because the shader works and the
findings are worth more than the code.

## What works

`fold.frag.in` is a Hyprland screen shader. It fakes the 3D fold - a fragment
shader cannot rotate a plane, so the image is squeezed into a trapezoid whose
far edge is narrower, higher, blurrier and darker. Sixteen taps on a golden
angle spiral: rings of six showed their spokes once the radius grew, because
several samples landed on the same bearing.

Two things about Hyprland screen shaders that cost an afternoon to find:

* They must declare `#version 300 es`. The compositor's vertex shader does,
  and GLSL refuses to link stages that disagree. Which also means the modern
  spellings: `in`, `texture`, an `out` variable instead of `gl_FragColor`.
* There is **no way to pass a uniform**. The fold amount is written into the
  source and the file re-applied, which costs a compile - 13 to 135 ms. Doing
  that per frame gives about seven frames a second.

The way round that is the `time` uniform, which **restarts at zero every time
the shader is applied**. So the shader is handed a pair of numbers - where the
fold is now, where it is going - and eases between them itself at full frame
rate. Verified by rendering `time` into pixels and reading them back with grim.
Using `time` requires `debug:damage_tracking = 0`, so `duo.py` switches it off
only while the effect is on screen.

## What does not work

The angle. This ThinkPad has two accelerometers, one in the lid and one in the
base, and a firmware `hinge` sensor that would report the angle directly. On
this machine:

* the base accelerometer (`iio:device3`) is live;
* the lid accelerometer (`iio:device1`) is **frozen** - it returns the same
  value forever, does not wake when its IIO buffer is enabled, streams nothing
  to `/dev/iio:device1` even for root, and is not claimed by
  `iio-sensor-proxy`;
* the `hinge` device reads zero on all three channels for the same reason.

So `duo.py` computes an angle that never changes. The effect itself can be
driven by hand - call `Fold().aim(0.6)` - and looks right.

## Where to pick it up

Hyprland sees the lid as a switch device (`hyprctl devices` lists "Lid
Switch") and takes binds on `switch:on:Lid Switch` and `switch:off:...`. That
turns the effect into an animation on close and open rather than something
that follows the hinge - which is what the Windows and macOS versions of this
do anyway, since they hook the lid event too.

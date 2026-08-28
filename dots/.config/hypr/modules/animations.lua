-- Curves, animations and gestures.

hl.curve("ii", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("smooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "ii", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "quick", style = "popin 90%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "ii", style = "slide" })
-- Layer surfaces scale in like windows do. The launcher opts out of this via
-- a no_anim layer rule further down - see the comment there.
-- speed is a duration in deciseconds, so 2.5 = 250 ms. Higher is slower, and
-- fractions are fine - Hyprland stores this as a float.
-- Picked by eye against 400 (the old value, heavy), 300 and 200 (abrupt).
-- Most of the character comes from the "ii" curve above, which starts fast and
-- overshoots slightly; swapping the curve changes the feel far more than a
-- step of this number does.
hl.animation({ leaf = "layers", enabled = true, speed = 2.5, bezier = "ii", style = "popin 90%" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

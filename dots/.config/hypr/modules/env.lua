-- Output and environment.
--
-- Set before anything else: the scale decides what every pixel value in
-- settings.lua and in waybar, kitty, fuzzel and mako is calibrated against.

-- Native resolution, no scaling. The panel is 13.3" 1920x1080 = 166 DPI, and
-- Hyprland's automatic scale picks 1.5 for that, which leaves only 1280x720 of
-- logical workspace. Pinning scale 1 gives the full 1920x1080 to work in, and
-- being an integer scale it also drops the fractional-scale side effects:
-- XWayland stops being resampled, and fuzzel no longer resizes itself right
-- after opening (see the launcher layer rule).
--
-- Everything sized in pixels below was multiplied by 1.5 to compensate - gaps,
-- rounding, cursor, shadow - and the same was done across waybar, kitty,
-- fuzzel, mako, GTK, hyprlock and the cheatsheet.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_SIZE", "36")
hl.env("HYPRCURSOR_SIZE", "36")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

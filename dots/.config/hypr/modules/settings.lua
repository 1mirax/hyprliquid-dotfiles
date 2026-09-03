-- General appearance and input.
--
-- Every length here is in logical pixels, and the monitor runs at scale 1
-- (see env.lua), so these are physical pixels too.

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    ["col.active_border"] = "rgba(ffffff45)",
    ["col.inactive_border"] = "rgba(ffffff12)",
    layout = "dwindle",
    resize_on_border = true,
  },
  decoration = {
    rounding = 18,
    active_opacity = 1.0,
    inactive_opacity = 0.95,
    blur = {
      enabled = true,
      size = 4,
      passes = 2,
      xray = false,
      new_optimizations = true,
      ignore_opacity = true,
      noise = 0.015,
      brightness = 1.1,
      contrast = 1.1,
      -- Blur menus and tooltips too, not just windows. Without this a
      -- right-click menu is a flat opaque rectangle over blurred glass.
      popups = true,
      popups_ignorealpha = 0.2,
      -- Darkens the blurred backdrop instead of leaving it milky, which is
      -- what keeps light text readable over a bright wallpaper.
      vibrancy_darkness = 0.4,
    },
    shadow = {
      enabled = true,
      range = 22,
      render_power = 2,
      color = "rgba(00000045)",
    },
  },
  input = {
    kb_layout = "us,ru",
    kb_options = "grp:alt_shift_toggle",
    follow_mouse = 1,
    numlock_by_default = true,
    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
      tap_to_click = true,
      scroll_factor = 0.4,
    },
  },
  dwindle = {
    preserve_split = true,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    focus_on_activate = true,
    animate_manual_resizes = false,
  },
})

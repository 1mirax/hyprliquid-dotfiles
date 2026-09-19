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
    -- How much the dimaround rule darkens by. Only the two fuzzel layer rules
    -- in modules/rules.lua use it, so this is effectively the launcher's dim.
    -- Hyprland's default is 0.4, which buried the desktop rather than pushing
    -- it back.
    dim_around = 0.25,

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
    -- numlock_by_default is deliberately absent, not false. On a keyboard with
    -- a real numeric block it saves one keypress per login; on one without it -
    -- the second machine here - NumLock turns the right-hand letters into a
    -- numeric overlay, so `u` types 4 and `j` types 1, at every login, until
    -- you work out what happened. The cost is not symmetric.
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
    -- An escape hatch, not decoration. If hyprlock dies while the session is
    -- locked, the compositor keeps the lock in place and the screen stays
    -- black with no way to type a password - a reboot. With this on, a lock
    -- screen can be put back over it from a TTY:
    --   Ctrl+Alt+F2, log in, then
    --   hyprctl --instance 0 dispatch exec hyprlock
    allow_session_lock_restore = true,
    disable_splash_rendering = true,
    focus_on_activate = true,
    animate_manual_resizes = false,
  },
})

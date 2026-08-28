local mod = "SUPER"
local term = "kitty"
local menu = "fuzzel"
local files = "nemo"
local browser = "firefox"

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

-- Autostart runs from the hyprland.start event, NOT at config-parse time.
-- exec_cmd at the top level fires before the compositor has an output or a
-- usable Wayland socket (the [executor] lines land before GL init in the log),
-- so waybar / hyprpaper / hypridle started there exit immediately and the
-- session comes up bare. mako only survived because dbus re-activates it.
--
-- The Lua API has no exec_once either: exec_cmd runs again on every reload,
-- so each command stays pgrep-guarded to avoid piling up duplicates.
local LOG = "$HOME/.cache/hypr-autostart.log"

-- Only the skip/start line goes to the log; the daemon's own stdout/stderr is
-- discarded. Otherwise waybar and hypridle keep writing into it for the whole
-- session and the file grows without bound.
-- Step aside when the session is managed by systemd (uwsm): there the daemons
-- come from their own user units. Booting the plain Hyprland entry still works,
-- this autostart takes over there as before.
--
-- The probe is an env var, not `systemctl is-active graphical-session.target`:
-- that target only goes active AFTER Hyprland has fired hyprland.start, so the
-- check always lost the race and both sides started everything (two waybars,
-- and mako.service died on the busy dbus name). uwsm exports UWSM_* into the
-- compositor environment before launch, and children inherit it.
local SYSTEMD = "[ -n \"$UWSM_FINALIZE_VARNAMES\" ]"

local function guard(probe, cmd)
  local label = cmd:gsub("'", "")
  hl.exec_cmd("if " .. SYSTEMD .. "; then " ..
    "echo 'systemd: " .. label .. "' >>" .. LOG .. "; exit 0; fi; " ..
    "if " .. probe .. " >/dev/null 2>&1; then " ..
    "echo 'skip: " .. label .. "' >>" .. LOG .. "; else " ..
    "echo 'start: " .. label .. "' >>" .. LOG .. "; " ..
    cmd .. " >/dev/null 2>&1; fi")
end

-- Always probe by process NAME (comm). The sh -c wrapper is named "sh", so it
-- can never match itself. `pgrep -f` is unusable here: the wrapper's own
-- cmdline carries the command verbatim, so the probe matched the wrapper and
-- the daemon was skipped forever - that silently killed wl-paste and the
-- polkit agent on every boot. Bracketing a letter does not help, because the
-- literal command sits in the same cmdline next to the pattern.
--
-- Matching by name also survives an absolute path: dbus activates mako as
-- /usr/bin/mako, which an anchored `pgrep -f '^mako$'` would miss.
local function once(name, cmd)
  guard("pgrep -x " .. name, cmd)
end

-- Same binary twice, told apart by an argument. Filtering pgrep's OUTPUT is
-- safe; filtering the process table is not.
local function once_arg(name, arg, cmd)
  guard("pgrep -ax " .. name .. " | grep -q -- '" .. arg .. "'", cmd)
end

-- fresh = true truncates the log, so it only ever holds the current session.
local function autostart(fresh)
  local redir = fresh and ">" or ">>"
  hl.exec_cmd("echo \"--- autostart $(date '+%H:%M:%S') ---\" " .. redir .. LOG)

  -- comm is truncated to 15 chars, hence polkit-gnome-au
  once("polkit-gnome-au", "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  once("waybar", "waybar")
  once("mako", "mako")
  once("hypridle", "hypridle")
  once_arg("wl-paste", "--type text", "wl-paste --type text --watch cliphist store")
  once_arg("wl-paste", "--type image", "wl-paste --type image --watch cliphist store")

  -- The wallpaper path lives in ~/.config/hypr/wallpaper, not here.
  -- The script also re-derives the accent colours with wallust.
  hl.exec_cmd("if " .. SYSTEMD .. "; then echo 'systemd: wallpaper' >>" .. LOG ..
    "; exit 0; fi; " ..
    "{ pgrep -x hyprpaper >/dev/null 2>&1 || hyprpaper & } ; " ..
    "~/.config/hypr/scripts/wallpaper.sh restore >>" .. LOG .. " 2>&1 " ..
    "&& echo 'wallpaper restored' >>" .. LOG)
end

hl.on("hyprland.start", function() autostart(true) end)

-- Safety net: if hyprland.start ever fails to fire we would come up with no
-- bar at all, so run autostart once more shortly after. The pgrep guards make
-- the second pass a no-op when the first one already worked.
hl.timer(function() autostart(false) end, { timeout = 3000, type = "oneshot" })

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 12,
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

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term), { description = "Apps: Terminal" })
hl.bind(mod .. " + T", hl.dsp.exec_cmd(term), { description = "Apps: Terminal" })
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(term), { description = "Apps: Terminal" })
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files), { description = "Apps: File manager" })
hl.bind(mod .. " + W", hl.dsp.exec_cmd(browser), { description = "Apps: Browser" })

hl.bind(mod .. " + D", hl.dsp.exec_cmd("pkill " .. menu .. " || " .. menu), { description = "Apps: Launcher" })
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("pkill " .. menu .. " || " .. menu), { description = "Apps: Launcher" })

hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("ALT + F4", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill(), { description = "Window: Kill (force)" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind(mod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Toggle floating" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }), { description = "Window: Pseudotile" })
hl.bind(mod .. " + C", hl.dsp.window.center(), { description = "Window: Center" })

hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), { description = "Scratchpad: Toggle" })
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }), { description = "Scratchpad: Move window there" })

hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus: Left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus: Right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus: Up" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus: Down" })

hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }), { description = "Move window: Left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window: Right" })
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }), { description = "Move window: Up" })
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }), { description = "Move window: Down" })

-- Workspace cycling (illogical-impulse style): r+-1 is relative to the current monitor.
hl.bind(mod .. " + CTRL + left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Previous" })
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Next" })
hl.bind(mod .. " + CTRL + up", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Previous" })
hl.bind(mod .. " + CTRL + down", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Next" })

-- Resize moved here. relative = true is required: without it x/y mean absolute size.
hl.bind(mod .. " + ALT + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true, description = "Resize: Narrower" })
hl.bind(mod .. " + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true, description = "Resize: Wider" })
hl.bind(mod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true, description = "Resize: Shorter" })
hl.bind(mod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true, description = "Resize: Taller" })

for i = 1, 9 do
  hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }),
    { description = "Workspace: Go to " .. i })
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }),
    { description = "Workspace: Move window to " .. i })
end
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = "10" }), { description = "Workspace: Go to 10" })
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10", follow = false }), { description = "Workspace: Move window to 10" })

hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace: Cycle forward" })
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace: Cycle back" })

hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"), { description = "Capture: Region to clipboard" })
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { description = "Capture: Screen to clipboard" })
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("grim ~/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png"), { description = "Capture: Screen to file" })
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Capture: Colour picker" })

hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | " .. menu .. " --dmenu | cliphist decode | wl-copy"), { description = "Clipboard: History" })

hl.bind(mod .. " + N", hl.dsp.exec_cmd("makoctl dismiss -a"), { description = "Notifications: Dismiss all" })
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("makoctl mode -t do-not-disturb"), { description = "Notifications: Do not disturb" })
hl.bind(mod .. " + CTRL + N", hl.dsp.exec_cmd("makoctl restore"), { description = "Notifications: Restore last" })

hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper.sh pick"), { description = "Wallpaper: Pick" })
hl.bind(mod .. " + CTRL + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper.sh random"), { description = "Wallpaper: Random" })

-- No pkill here on purpose: `pkill -f cheatsheet.py` matches the sh wrapper
-- that carries that very string and kills itself instead. The script toggles
-- itself through a pidfile holding the fuzzel child's pid.
hl.bind(mod .. " + Slash", hl.dsp.exec_cmd("~/.config/hypr/scripts/cheatsheet.py"),
  { description = "Session: Keybind cheatsheet" })

hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit(), { description = "Session: Exit Hyprland" })
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("pkill fuzzel || fuzzel"), { release = true })
hl.bind(mod .. " + CTRL + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Session: Reload config" })

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"), { locked = true, description = "Media: Mute" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { locked = true, repeating = true, description = "Media: Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { locked = true, repeating = true, description = "Media: Volume down" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -t"), { locked = true, description = "Media: Mute microphone" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true, description = "Display: Brighter" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true, description = "Display: Dimmer" })

hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })
hl.window_rule({ match = { class = "^(nemo)$", title = "^(Properties)$" }, float = true })
-- No opacity rule for kitty: transparency comes from background_opacity in
-- kitty.conf. Stacking both would multiply and wash the text out.
-- No opacity rule for nemo: the glass comes from ~/.config/gtk-3.0/gtk.css,
-- which keeps text opaque. A window rule would fade the text along with it.
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- blur_popups covers the bar's own tooltips and dropdowns (the calendar on
-- the clock, the volume tooltip), which are separate surfaces.
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, blur_popups = true })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.1 })
-- fuzzel registers as "launcher", not "fuzzel" - verified by watching
-- hyprctl layers while it was open. A rule matching "fuzzel" never fired.
-- ignore_alpha must stay below the launcher's own 0.063 background alpha,
-- otherwise its most transparent parts are skipped by the blur.
-- The launcher animates like every other layer, but only because the monitor
-- runs at scale 1. fuzzel cannot know its final size before its surface is
-- mapped - the font size depends on the scale, which the compositor reports
-- afterwards - so it maps a placeholder frame and re-lays out once
-- wp_fractional_scale_v1 arrives (codeberg dnkl/fuzzel#463). At scale 1.5 that
-- meant set_size(354, 316) followed by set_size(344, 319) ~140 ms later, and
-- since a layer animation moves geometry, it chased the change and the right
-- edge visibly dragged. Styles do not dodge it: "fade" was tried both as the
-- global animation:layers style and as this rule's own, and the drag returned
-- both times. Upstream's answer is noanim.
--
-- At scale 1 fuzzel's initial guess is already correct - measured, one commit
-- at 354x324 instead of two - so there is nothing left to chase. If the
-- monitor ever goes back to a fractional scale, add no_anim = true here.
hl.layer_rule({ match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.03 })
-- The cheatsheet is fuzzel in dmenu mode, launched with --namespace cheatsheet
-- so it can be told apart from the launcher. Same glass, same ignore_alpha
-- (the background is ffffff10, so the threshold has to sit below 0.063), plus
-- dim_around to push the desktop back while a list of keys is being read.
hl.layer_rule({ match = { namespace = "cheatsheet" },
  blur = true, ignore_alpha = 0.03, dim_around = true })

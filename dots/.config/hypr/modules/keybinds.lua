-- Key bindings.
--
-- Every bind carries a description in "Category: Action" form. That is not
-- decoration: scripts/cheatsheet.py reads them back out of `hyprctl binds -j`
-- to build the searchable keybind list, so a bind without one is invisible
-- there, and the text before the colon decides its grouping.

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

-- Bluetooth: bzmenu, wrapped in a script so waybar's on-click shares it.
hl.bind(mod .. " + B", hl.dsp.exec_cmd("~/.config/hypr/scripts/bluetooth-menu.sh"),
  { description = "Network: Bluetooth" })

-- Kept aside as a fallback: pure bluetoothctl, works with nothing installed
-- beyond bluez-utils and fuzzel.
hl.bind(mod .. " + ALT + B", hl.dsp.exec_cmd("~/.config/hypr/scripts/bluetooth.sh"),
  { description = "Network: Bluetooth (fallback)" })

-- Wi-Fi: still deciding between networkmanager_dmenu and our own script.
hl.bind(mod .. " + I", hl.dsp.exec_cmd("networkmanager_dmenu"),
  { description = "Network: Wi-Fi" })
hl.bind(mod .. " + SHIFT + I", hl.dsp.exec_cmd("~/.config/hypr/scripts/network.sh"),
  { description = "Network: Wi-Fi (our script)" })

hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit(), { description = "Session: Exit Hyprland" })
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("pkill fuzzel || fuzzel"), { release = true })
hl.bind(mod .. " + CTRL + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Session: Reload config" })

-- wpctl ships with wireplumber and talks to PipeWire directly, so no pamixer
-- and no detour through the PulseAudio compatibility socket.
--
-- @DEFAULT_AUDIO_SINK@ is resolved at press time, so these follow Bluetooth
-- headphones the moment they become the default output.
--
-- -l 1.0 is not optional: unlike pamixer, wpctl has no ceiling of its own, and
-- without the limit a held key walks past 100% into software gain - which
-- clips, and is dangerous in headphones. Lowering needs no limit; zero is one.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Media: Mute" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Media: Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true, description = "Media: Volume down" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Media: Mute microphone" })

hl.bind(mod .. " + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-menu.sh"),
  { description = "Media: Audio devices" })

-- Profiles are a separate key rather than a step inside the audio menu: pwmenu
-- does not cover them, and putting them behind a first-level choice would add
-- a keystroke to the common case of just picking an output.
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/audio-profile.sh"),
  { description = "Media: Audio profile" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true, description = "Display: Brighter" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true, description = "Display: Dimmer" })

-- Hyprland configuration, split into modules under hypr/modules/.
--
-- This is the Lua config, not hyprland.conf. The API is experimental and
-- differs from every guide out there in ways that are commented where they
-- bite - notably there is no exec_once (see modules/autostart.lua) and
-- `hyprctl keyword` does nothing, so runtime changes need `hyprctl eval`.
--
-- Order matters. vars must come first because the others read it, and env sets
-- the monitor scale that every pixel value further down is calibrated for.

require("modules.vars")
require("modules.env")
require("modules.autostart")
require("modules.settings")
require("modules.animations")
require("modules.keybinds")
require("modules.rules")
require("modules.workspaces")

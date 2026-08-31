-- Workspace buttons: the state feed behind scripts/workspace.sh.
--
-- waybar polls nothing here. The compositor already knows when a workspace
-- changed, so it refreshes the cache and raises SIGRTMIN+1; every custom/wsN
-- module is declared with "signal": 1 and re-runs on it. That keeps the bar
-- event-driven, the way the mpris module is, instead of adding a fourth timer.
--
-- Occupancy has to be watched as well as focus: opening the only window on a
-- workspace, or closing it, changes a button's class without the active
-- workspace moving at all.
local SCRIPT = "~/.config/hypr/scripts/workspace.sh"

local function refresh()
  hl.exec_cmd(SCRIPT .. " state && pkill -RTMIN+1 waybar")
end

-- These names are exact and were checked against what Hyprland accepts, not
-- guessed: it rejects an unknown one at parse time and paints the whole config
-- error banner over the screen. The full list this build knows is
--
--   input.keyboard.key  keybinds.submap  screenshare.state
--   window.open  window.open_early  window.close  window.destroy  window.kill
--   window.active  window.title  window.class  window.pin  window.urgent
--   window.fullscreen  window.update_rules  window.move_to_workspace
--   workspace.created  workspace.removed  workspace.active
--   workspace.special_active  workspace.move_to_monitor
--   monitor.added  monitor.removed  monitor.focused  monitor.layout_changed
--   layer.opened  layer.closed
--   config.reloaded  config.props_refreshed  hyprland.start  hyprland.shutdown
--
-- so "workspace.destroyed", "window.opened", "window.closed" and
-- "window.moved" are all wrong, however natural they read.
for _, event in ipairs({
  "workspace.active",           -- focus moved
  "workspace.created",
  "workspace.removed",
  "window.open",                -- occupancy of one workspace changed
  "window.close",
  "window.move_to_workspace",   -- occupancy of two changed at once
}) do
  hl.on(event, refresh)
end

-- waybar is not up yet when hyprland.start fires, so the cache is primed here
-- and the modules build their first state from it themselves.
hl.on("hyprland.start", function() hl.exec_cmd(SCRIPT .. " state") end)

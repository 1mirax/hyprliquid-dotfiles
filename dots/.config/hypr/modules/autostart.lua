-- Starting the session's daemons when systemd is not doing it.

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

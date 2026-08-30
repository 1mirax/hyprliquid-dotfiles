# hyprliquid-dotfiles

An iOS-flavoured "liquid glass" Hyprland setup for a ThinkPad X390 Yoga —
translucent surfaces, compositor blur, and a bar, launcher and notifications
that look like one piece rather than three programs.

Built on Arch with **Hyprland 0.56.2 and its Lua configuration**, which is the
unusual part: there is no `hyprland.conf` here, only `hyprland.lua`. The Lua
API is experimental and sparsely documented, so several things work
differently from every guide you will find — those are all commented in place.

## What is in here

| | |
|---|---|
| Compositor | Hyprland (Lua config), hypridle, hyprlock, hyprpaper |
| Session | uwsm — daemons run as systemd user units, with a guarded fallback |
| Bar | waybar, built-in modules only |
| Launcher | fuzzel — also the wallpaper picker, clipboard history and cheatsheet |
| Notifications | mako |
| Terminal | kitty with a cursor trail |
| Shell | fish, with its own `simple` prompt and a neutral palette |
| Power | TLP + throttled, with a tested undervolt |

## Install

```sh
git clone https://github.com/1mirax/hyprliquid-dotfiles ~/Projects/hyprliquid-dotfiles
cd ~/Projects/hyprliquid-dotfiles

sudo pacman -S --needed - < packages.txt   # read it first; two optional AUR menus at its end
./install.sh --dry-run                     # see exactly what will happen
./install.sh
```

`install.sh` symlinks everything from `dots/` into `$HOME`, so editing a config
in `~/.config` edits this repository and `git status` shows it. Whatever is
already in the way is moved aside with a timestamp and recorded, and
`./install.sh --unlink` puts it all back.

It also does the things that are not files: renders `hyprlock.conf` from its
template, generates small icon variants, and enables the user services.

Packages and the power stack are left to you on purpose — see the notes the
script prints at the end. **The undervolt values are specific to one CPU
sample; too large a value panics the kernel.** Read
`dots/.config/power/throttled.conf` before installing it.

## Layout

```
dots/                       everything that gets symlinked into $HOME
  .config/hypr/             hyprland.lua, hypridle, hyprlock template, scripts/
  .config/waybar/           config.jsonc + style.css
  .config/fuzzel/           launcher, and every picker in the setup
  .config/power/            tlp.conf, throttled.conf, and their installer
  .local/share/applications/  NoDisplay overrides that hide menu clutter
install.sh                  linking, templates, icons, unit enabling
packages.txt                every dependency, verified against a working install
```

## Things worth knowing

A few of these took a while to find, and each is commented where it applies.

**The monitor runs at scale 1, not the 1.5 Hyprland picks by itself.** At 13.3"
and 1920x1080 the automatic scale leaves 1280x720 of workspace, which is
cramped. Everything sized in pixels is calibrated for scale 1 — changing the
scale means rescaling all of it.

**Fractional scaling breaks the launcher's open animation.** fuzzel cannot know
its size before its surface is mapped, so it maps a placeholder and re-lays out
once the real scale arrives. A layer animation chases that resize and the edge
drags. Upstream's answer is `noanim`; scale 1 removes the resize entirely and
the animation works again.

**Hyprland's Lua config has no `exec_once`, and `hyprctl keyword` does nothing.**
Autostart hangs off the `hyprland.start` event with a timer as a fallback, and
runtime changes need `hyprctl eval` instead.

**waybar spawns no shell processes.** Temperature and media come from built-in
modules rather than `exec` scripts, which took the fork rate from 83 to 12 per
20 seconds.

**The terminal palette is deliberately near-monochrome.** Tokens are told
apart by lightness and a faint temperature bias rather than by hue; only red
keeps real saturation, because an error has to shout. Push any of the sixteen
colours past roughly 20% saturation and the neutrality is gone.

**Applications that ship only a 512x512 icon make the launcher slow.** One of
them cost 34 ms of a 90 ms startup. `fix-oversized-icons.py` finds them all and
generates small variants under `~/.local/share/icons`.

## Credits

The keybinding conventions, the cheatsheet idea and the launcher's animation
curve come from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
(illogical-impulse). Some blur and layer-rule details were picked up from
[sunwoo101/dotfiles](https://github.com/sunwoo101/dotfiles).

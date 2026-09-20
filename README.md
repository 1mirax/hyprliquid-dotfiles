# hyprliquid-dotfiles

An iOS-flavoured "liquid glass" Hyprland setup — translucent surfaces,
compositor blur, and a bar, launcher and notifications that look like one
piece rather than three programs.

It is one configuration for every machine, not a variant per host: the monitor
rule matches whatever the built-in panel is called, and the only genuinely
hardware-specific part, the undervolt, installs itself as zeros on any CPU but
the one it was tested on. Developed on a ThinkPad X390 Yoga.

Built on Arch with **Hyprland 0.56.2 and its Lua configuration**, which is the
unusual part: there is no `hyprland.conf` here, only `hyprland.lua`. The Lua
API is experimental and sparsely documented, so several things work
differently from every guide you will find — those are all commented in place.

## What is in here

| | |
|---|---|
| Compositor | Hyprland (Lua config), hypridle, hyprlock, swaybg |
| Session | uwsm — daemons run as systemd user units, with a guarded fallback |
| Bar | waybar, built-in modules only |
| Launcher | fuzzel — also the wallpaper picker, clipboard history and cheatsheet |
| Notifications | mako |
| Terminal | alacritty |
| Shell | fish, with its own `simple` prompt and a neutral palette |
| Power | TLP + throttled, with a tested undervolt |

## Install

```sh
git clone https://github.com/1mirax/hyprliquid-dotfiles ~/Projects/hyprliquid-dotfiles
cd ~/Projects/hyprliquid-dotfiles

# pacman understands neither comments nor the whitespace that lined them up
sed 's/#.*//' packages.txt | awk 'NF{print $1}' | sudo pacman -S --needed -

./install.sh --dry-run                     # see exactly what will happen
./install.sh
```

Read `packages.txt` first — three optional AUR menus are listed at its end.
Two things it cannot do for you:

```sh
chsh -s /usr/bin/fish                      # the prompt and palette assume fish
sudo systemctl enable ly@tty2.service      # then pick "Hyprland (uwsm)"
```

### From a blank disk

`alis/` holds a configuration for [alis](https://github.com/picodotdev/alis)
that installs Arch the way these machines are installed — no encryption, ext4
on one disk, no desktop environment, and the package list from `packages.txt`,
which it reads rather than repeats. From the live image:

```sh
pacman -Sy --noconfirm git
git clone https://github.com/1mirax/hyprliquid-dotfiles
cd hyprliquid-dotfiles/alis
./fetch.sh          # downloads alis, keeps the two configs in this repo
./alis.sh
```

`fetch.sh` rather than a plain `curl` of `alis.sh`: alis is a tree, not a
file — `alis.sh` sources `alis-commons.sh` and `alis-commons.conf` and calls
into `configs/` and `files/`. Upstream's own `download.sh` brings all of it
*and* its own `alis.conf`, which would replace this one; `fetch.sh` copies
everything except the two configs here, then prints `lsblk` and the `DEVICE`
line so the target disk is the last thing you see before starting.

**Check `DEVICE` in `alis/alis.conf` before running it.** `PARTITION_MODE="auto"`
deletes every partition on it, and the installation USB is in the same `lsblk`
listing. It is pinned to `/dev/mmcblk0` here, which is the eMMC on the machine
it was written for — change it to the disk you mean.

If the live image has no network yet, `iwctl` brings up Wi-Fi before anything
else:

```sh
iwctl station wlan0 scan
iwctl station wlan0 get-networks
iwctl station wlan0 connect "<SSID>"     # asks for the passphrase
ping -c1 archlinux.org
```

alis stops at a bootable Arch — base, kernel, video driver, bootloader,
NetworkManager — and does **not** install the package list. That happens on
the installed system, along with everything else:

```sh
sudo pacman -Sy --needed git
git clone https://github.com/1mirax/hyprliquid-dotfiles ~/Projects/hyprliquid-dotfiles
cd ~/Projects/hyprliquid-dotfiles
sed 's/#.*//' packages.txt | awk 'NF{print $1}' | sudo pacman -S --needed -
./install.sh

sudo bash ~/.config/power/install.sh
sudo systemctl enable ly@tty2.service bluetooth.service
chsh -s /usr/bin/fish
mkdir -p ~/Pictures/wallpapers
```

### On a system that already runs

`install.sh` symlinks everything from `dots/` into `$HOME`, so editing a config
in `~/.config` edits this repository and `git status` shows it. Whatever is
already in the way is moved aside with a timestamp and recorded, and
`./install.sh --unlink` puts it all back.

It also does the things that are not files: renders `hyprlock.conf` from its
template, generates small icon variants, and enables the user services.

Packages and the power stack are left to you on purpose — see the notes the
script prints at the end.

The power installer reads the machine before it writes anything. On a
ThinkPad it installs TLP and throttled; anywhere else throttled is skipped
entirely, because its package power limits were chosen for a 15 W chassis and
raising a limit past what a machine was cooled for is a thermal problem rather
than a tuning one. **The undervolt goes further still: it installs as zeros on
any CPU but the one it was walked down to a kernel panic on.** TLP — governors,
EPP, ASPM, runtime PM, radio power — applies everywhere.

## Layout

```
dots/                       everything that gets symlinked into $HOME
  .config/hypr/             hyprland.lua, hypridle, hyprlock template, scripts/
  .config/waybar/           config.jsonc + style.css
  .config/fuzzel/           launcher, and every picker in the setup
  .config/power/            tlp.conf, throttled.conf, and the installer that
                            places them and leaves Bluetooth off at boot
  .local/share/applications/  NoDisplay overrides that hide menu clutter
alis/                       installing Arch itself on a blank disk
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

**Enabling greetd is not enough to boot into it.** Its unit declares only
`Alias=display-manager.service` and no `WantedBy`, and that alias is pulled by
`graphical.target`. This machine's default target was `multi-user.target` -
where ly used to start, because ly's unit said `WantedBy=multi-user.target`
outright - so the first boot after the switch ended at a bare console with
greetd enabled, running, and wanted by nothing. `systemctl set-default
graphical.target` is the missing half; `greetd/install.sh` now checks for it.

**Waking from suspend left a black screen because a table key was wrong.**
`hl.dsp.dpms` takes `action`, and hypridle's config passed `status`. An
unrecognised key is not an error - the dispatcher sees an empty table and
falls back to toggling - so every "turn the screen on" in that file was
really "flip the screen". Waking with the panel already on turned it off,
which is why it looked random. Nothing reports this: check the state with
`hyprctl monitors -j` rather than trusting that a dispatcher did what its
argument says. Two changes came out of the hunt and stayed:
`before_sleep_cmd` wakes the output before locking, so S3 is never entered
with the output disabled, and `misc:allow_session_lock_restore` lets a TTY
put a working lock screen back over a dead one
(`hyprctl --instance 0 dispatch exec hyprlock`) instead of needing a reboot.
`power/install.sh` also installs a service that copies the compositor's log
out of `/run` after every wake into `~/.local/state/hypr-resume`, since
`/run` is wiped by the reboot that used to end these sessions.

**Applications that ship only a 512x512 icon make the launcher slow.** One of
them cost 34 ms of a 90 ms startup. `fix-oversized-icons.py` finds them all and
generates small variants under `~/.local/share/icons`.

## Credits

The keybinding conventions, the cheatsheet idea and the launcher's animation
curve come from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
(illogical-impulse). Some blur and layer-rule details were picked up from
[sunwoo101/dotfiles](https://github.com/sunwoo101/dotfiles).

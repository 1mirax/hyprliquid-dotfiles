#!/usr/bin/env python3
"""Wi-Fi picker for fuzzel, talking to NetworkManager over libnm.

Why this exists rather than networkmanager_dmenu, which does the same job in
1490 lines: that one is a front end to all of NetworkManager - VPN, WWAN,
Bluetooth tethering, hotspots, VLANs - and for this machine all of that is
either handled elsewhere (Amnezia runs its own tunnel, bzmenu owns Bluetooth)
or does not exist (no modem). What it cannot do is the one thing that was
actually wrong: it hands the connection to NetworkManager and stops watching,
so you pick a network and then stare at nothing for ten seconds.

Three deliberate differences:

  * It scans on open and waits for the result. NetworkManager stops scanning
    once you are connected and its results age out within minutes, so opening
    a menu usually showed one network - the current one - and you had to pick
    "Rescan" and open it again. Measured on this machine: a scan takes 2.8s.
    Three seconds once beats a stale list and a second trip.

  * It watches the device through the connection and rewrites one notification
    in place - preparing, authenticating, getting an address, connected - so
    the wait is legible. mako replaces by the synchronous hint, the same way
    osd.sh does for volume.

  * The list is columns, not a sentence: marker, bars, security, name.

The libnm idioms here - ssid_to_utf8, the security flag parsing, the profile
built for a new network - are taken from networkmanager_dmenu, which got them
from NetworkManager's own python examples. No reason to reinvent those.
"""

import os
import signal
import subprocess
import sys
import uuid

import gi

gi.require_version("NM", "1.0")
from gi.repository import GLib, NM  # noqa: E402

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PIDFILE = os.path.join(RUNTIME, "hypr-network-picker.pid")

# Same namespace as every other menu, or the launcher animation will not match.
FUZZEL = [
    "fuzzel", "--dmenu", "--namespace", "cheatsheet",
    "--lines", "14", "--width", "52",
]

# One notification, rewritten in place. Same mechanism osd.sh uses.
TAG = "string:x-canonical-private-synchronous:wifi"

# How long to wait for a scan, and for a connection to settle.
SCAN_TIMEOUT = 8
CONNECT_TIMEOUT = 45

# The action rows under the network list. The marker keeps them apart from
# network names without a separator row that can itself be selected.
ACT = "› "


def notify(summary, body="", urgency="low"):
    subprocess.run(
        ["notify-send", "-a", "network", "-u", urgency, "-h", TAG, summary, body],
        check=False,
    )


def fuzzel(lines, prompt, password=False):
    """Run fuzzel as a dmenu and return the chosen line, or None."""
    cmd = FUZZEL + ["--prompt", prompt]
    if password:
        cmd += ["--password", "--lines", "0"]
    proc = subprocess.Popen(
        cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
    )
    # Remember the child so a second keypress closes the menu instead of
    # opening another one, the way power.sh does it.
    with open(PIDFILE, "w") as fh:
        fh.write(str(proc.pid))
    out, _ = proc.communicate("\n".join(lines))
    try:
        os.unlink(PIDFILE)
    except FileNotFoundError:
        pass
    out = out.strip("\n")
    return out or None


def already_open():
    """Second invocation closes the open menu and exits."""
    try:
        with open(PIDFILE) as fh:
            pid = int(fh.read().strip())
        # Check what the pid actually is before signalling it. A stale file
        # outlives its process, pids get reused, and a menu that kills a
        # random program because it inherited a number is worse than a menu
        # that opens twice.
        with open(f"/proc/{pid}/comm") as fh:
            if fh.read().strip() != "fuzzel":
                return False
        os.kill(pid, signal.SIGTERM)
        return True
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        return False


def ssid_to_utf8(ap):
    ssid = ap.get_ssid()
    return NM.utils_ssid_to_utf8(ssid.get_data()) if ssid else ""


def security(ap):
    """The strongest key management the AP advertises, as one short word."""
    wpa = ap.get_wpa_flags()
    rsn = ap.get_rsn_flags()
    sec_flags = getattr(NM, "80211ApSecurityFlags")
    if rsn & sec_flags.KEY_MGMT_SAE:
        return "WPA3"
    if (wpa | rsn) & sec_flags.KEY_MGMT_802_1X:
        return "802.1X"
    if rsn & sec_flags.KEY_MGMT_PSK:
        return "WPA2"
    if wpa:
        return "WPA"
    if ap.get_flags() & getattr(NM, "80211ApFlags").PRIVACY:
        return "WEP"
    return "open"


def bars(strength):
    """NM grades the signal into four steps; render them as a meter."""
    chars = "▂▄▆█"
    filled = NM.utils_wifi_strength_bars(strength).count("*")
    return chars[:filled].ljust(4)


def wifi_device(client):
    for dev in client.get_devices():
        if dev.get_device_type() == NM.DeviceType.WIFI:
            return dev
    return None


def scan(dev):
    """Ask for a fresh scan and wait for it, so the list is never stale."""
    before = dev.get_last_scan()
    loop = GLib.MainLoop()

    def done(*_):
        if dev.get_last_scan() != before:
            loop.quit()

    handler = dev.connect("notify::last-scan", done)
    dev.request_scan_async(None, None, None)
    GLib.timeout_add_seconds(SCAN_TIMEOUT, lambda: (loop.quit(), False)[1])
    loop.run()
    # handler_disconnect, not disconnect: NM.Device has a disconnect() of its
    # own that drops the device off the network, and it shadows GObject's.
    # Detaching a signal handler with the obvious name would have taken the
    # Wi-Fi down instead.
    dev.handler_disconnect(handler)


def saved_for(client, ssid):
    """The saved profile for this SSID, if this machine knows one."""
    for conn in client.get_connections():
        wireless = conn.get_setting_wireless()
        if wireless is None:
            continue
        raw = wireless.get_ssid()
        if raw and NM.utils_ssid_to_utf8(raw.get_data()) == ssid:
            return conn
    return None


def access_points(dev):
    """One entry per SSID, strongest first, hidden networks dropped."""
    seen = {}
    for ap in sorted(
        dev.get_access_points(), key=lambda a: a.get_strength(), reverse=True
    ):
        name = ssid_to_utf8(ap)
        if name and name not in seen:
            seen[name] = ap
    return seen


def watch_connection(dev, target):
    """Rewrite one notification as the device walks to ACTIVATED or FAILED.

    This is the whole reason for writing our own picker: nmcli and every dmenu
    wrapper around it fire the connection and walk away.
    """
    state = NM.DeviceState
    steps = {
        state.PREPARE: "Preparing",
        state.CONFIG: "Authenticating",
        state.NEED_AUTH: "Waiting for the password",
        state.IP_CONFIG: "Getting an address",
        state.IP_CHECK: "Checking the connection",
        state.SECONDARIES: "Almost there",
    }
    loop = GLib.MainLoop()
    result = {"ok": False, "started": False}

    def changed(_dev, new, _old, reason):
        if new in steps:
            result["started"] = True
            notify(f"Connecting to {target}", steps[new])
        elif new == state.ACTIVATED:
            result["ok"] = True
            notify(f"Connected to {target}")
            loop.quit()
        # DISCONNECTED only counts as failure once the attempt has begun:
        # switching from one network to another passes through it on the way
        # out of the old one, and reporting that as an error would fire before
        # the new connection had done anything at all.
        elif new == state.FAILED or (new == state.DISCONNECTED and result["started"]):
            why = NM.utils_enum_to_str(NM.DeviceStateReason, reason) or "failed"
            notify(f"Could not connect to {target}", why.replace("-", " "),
                   urgency="normal")
            loop.quit()

    handler = dev.connect("state-changed", changed)
    GLib.timeout_add_seconds(
        CONNECT_TIMEOUT,
        lambda: (notify(f"Could not connect to {target}", "Timed out",
                        urgency="normal"), loop.quit(), False)[2],
    )
    loop.run()
    dev.handler_disconnect(handler)  # see the note in scan()
    return result["ok"]


def profile_for(ap, dev, password):
    """A new NM profile for a network this machine has not seen before.

    Straight out of networkmanager_dmenu, which took it from NetworkManager's
    own examples. WPA3 wants sae where WPA2 wants wpa-psk; getting that wrong
    fails with a reason that does not mention key management at all.
    """
    profile = NM.SimpleConnection.new()

    s_con = NM.SettingConnection.new()
    s_con.set_property(NM.SETTING_CONNECTION_ID, ssid_to_utf8(ap))
    s_con.set_property(NM.SETTING_CONNECTION_UUID, str(uuid.uuid4()))
    s_con.set_property(NM.SETTING_CONNECTION_TYPE, "802-11-wireless")
    profile.add_setting(s_con)

    s_wifi = NM.SettingWireless.new()
    s_wifi.set_property(NM.SETTING_WIRELESS_SSID, ap.get_ssid())
    s_wifi.set_property(NM.SETTING_WIRELESS_MODE, "infrastructure")
    profile.add_setting(s_wifi)

    for setting, method in ((NM.SettingIP4Config, "auto"), (NM.SettingIP6Config, "auto")):
        s_ip = setting.new()
        s_ip.set_property(NM.SETTING_IP_CONFIG_METHOD, method)
        profile.add_setting(s_ip)

    sec = security(ap)
    if sec != "open":
        s_sec = NM.SettingWirelessSecurity.new()
        s_sec.set_property(
            NM.SETTING_WIRELESS_SECURITY_KEY_MGMT,
            "sae" if sec == "WPA3" else "wpa-psk",
        )
        s_sec.set_property(NM.SETTING_WIRELESS_SECURITY_PSK, password)
        profile.add_setting(s_sec)

    return profile


def connect(client, dev, ap, name, conn):
    """Activate a saved profile, or ask for a password and make one."""
    if conn is not None:
        client.activate_connection_async(conn, dev, None, None, None, None)
        return watch_connection(dev, name)

    password = ""
    if security(ap) != "open":
        password = fuzzel([], f"{name}  ", password=True)
        if not password:
            return False

    client.add_and_activate_connection_async(
        profile_for(ap, dev, password), dev, ap.get_path(), None, None, None
    )
    return watch_connection(dev, name)


def show_password(client, name):
    """Read the stored key and offer it without writing it anywhere.

    Retrieving secrets for your own connection needs no polkit prompt:
    settings.modify.own is allow_active yes. It is only ever available for a
    network this machine has actually saved.
    """
    conn = saved_for(client, name)
    if conn is None:
        notify("No saved password", f"{name} has never been connected here")
        return
    # Two steps, not one: get_secrets returns a GVariant, it does not fill the
    # connection object, so reading the setting straight afterwards gives an
    # empty key. update_secrets merges the variant back in. networkmanager_dmenu
    # sidesteps all of this by shelling out to `nmcli device wifi show-password`
    # in a terminal window, which is the thing this script exists not to do.
    try:
        secrets = conn.get_secrets("802-11-wireless-security", None)
        conn.update_secrets("802-11-wireless-security", secrets)
        key = conn.get_setting_wireless_security().get_psk()
    except Exception:
        key = None
    if not key:
        notify("No password stored", f"{name} may be an open network")
        return

    # Shown in the menu and nowhere else: no notification, so it stays out of
    # mako's history, and the clipboard only gets it if you ask.
    choice = fuzzel([key, ACT + "copy to clipboard"], f"{name}  ")
    if choice == ACT + "copy to clipboard":
        subprocess.run(["wl-copy", "--", key], check=False)
        notify("Password copied", name)


def forget(client, name):
    conn = saved_for(client, name)
    if conn is None:
        return
    conn.delete_async(None, None, None)
    notify("Forgotten", name)


def main():
    if already_open():
        return

    client = NM.Client.new(None)
    dev = wifi_device(client)
    if dev is None:
        notify("No Wi-Fi adapter", urgency="normal")
        return

    if not client.wireless_get_enabled():
        if fuzzel([ACT + "turn Wi-Fi on"], "wifi  "):
            client.wireless_set_enabled(True)
            notify("Wi-Fi", "Radio on")
        return

    notify("Scanning", "Looking for networks")
    scan(dev)

    active_ap = dev.get_active_access_point()
    active = ssid_to_utf8(active_ap) if active_ap else None
    aps = access_points(dev)

    # Active first, then networks this machine already knows, then the rest.
    # Each group keeps the signal order access_points() established.
    known = {n: saved_for(client, n) for n in aps}
    order = sorted(
        aps,
        key=lambda n: (n != active, known[n] is None),
    )

    rows = {}
    for name in order:
        ap = aps[name]
        mark = "●" if name == active else ("○" if known[name] else " ")
        row = f"{mark} {bars(ap.get_strength())}  {security(ap):<7} {name}"
        rows[row] = name

    menu = list(rows)
    if active:
        menu.append(ACT + f"disconnect from {active}")
        menu.append(ACT + f"show password for {active}")
        menu.append(ACT + f"forget {active}")
    menu.append(ACT + "turn Wi-Fi off")

    choice = fuzzel(menu, "wifi  ")
    if not choice:
        return

    if choice.startswith(ACT):
        action = choice[len(ACT):]
        if action == "turn Wi-Fi off":
            client.wireless_set_enabled(False)
            notify("Wi-Fi", "Radio off")
        elif action.startswith("disconnect from "):
            dev.disconnect_async(None, None, None)
            notify("Disconnected", active)
        elif action.startswith("show password for "):
            show_password(client, active)
        elif action.startswith("forget "):
            forget(client, active)
        return

    name = rows.get(choice)
    if not name or name == active:
        return
    connect(client, dev, aps[name], name, known[name])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)

# Wireless Display Kit for Arch Linux + KDE Plasma

Turn an Arch Linux laptop running KDE Plasma (Wayland) into a complete wireless-display station:

- **Send** your screen to a Samsung TV, projector or Chromecast (Miracast and Google Cast).
- **Receive** screens from an iPhone/iPad/Mac (AirPlay), an Android or Samsung phone (scrcpy, with a DeX-style desktop), or another PC (Moonlight/Sunshine).
- **Host a Wi-Fi hotspot** that runs *at the same time* as your normal Wi-Fi connection, so guests can join the laptop directly and use the receivers above.
- Two taskbar launchers with small Qt windows: **Wireless Display** (big icon buttons) and **Wi-Fi Hotspot** (QR code, Start/Stop, change password).

Everything here was built and tested on Arch Linux, KDE Plasma 6.8 (Wayland), an Intel Arrow Lake laptop with an Intel Wi-Fi 7 adapter and NetworkManager + firewalld.

---

## 1. Quick install

```bash
git clone <your-repo-url> wireless-display-kit
cd wireless-display-kit
./install.sh
```

The installer detects your Wi-Fi interface, installs packages, enables Avahi, offers to open firewall ports, installs the launchers, creates the hotspot profile and pins both launchers to the Plasma taskbar. Needs an AUR helper (`yay` or `paru`) for three packages.

Override the detected interface with `WIFI_IF=wlan0 ./install.sh`.

---

## 2. What gets installed

| Purpose | Package | Source |
|---|---|---|
| Miracast + Chromecast sender | `gnome-network-displays` | AUR |
| AirPlay receiver | `uxplay` | AUR |
| Cast files/URLs to Chromecast from CLI | `catt` | AUR |
| Android mirroring / DeX desktop | `scrcpy`, `android-tools`, `android-udev` | extra |
| Receive another PC's screen | `moonlight-qt` | extra |
| Video pipeline + codecs | `gst-plugins-good/bad/ugly`, `gst-libav`, `gst-plugin-pipewire`, `pipewire`, `wireplumber` | extra |
| Hardware H.264 encoding (Intel) | `intel-media-driver`, `libva-utils` | extra |
| Screen capture on Wayland/KDE | `xdg-desktop-portal-kde` | extra |
| Service discovery (mDNS) | `avahi` | extra |
| Launcher windows and QR codes | `python-pyqt6`, `qrencode`, `kdialog`, `iw` | extra |

Despite its name, GNOME Network Displays works perfectly on KDE: it uses the standard screencast portal that KDE provides.

### Check your hardware first

```bash
iw phy | grep -E 'P2P-client|P2P-GO|\* AP'
vainfo | grep -i h264
```

You want `P2P-client`, `P2P-GO` (Miracast) and `AP` (hotspot) listed, and an H264 `EncSlice` entry for hardware encoding.

---

## 3. Sending your screen (Miracast / Chromecast)

1. On the TV open **Sources → Screen Mirroring** (Samsung) or make sure the Chromecast is on the same Wi-Fi.
2. Click **Wireless Display → Cast to TV**.
3. Pick the TV in the list, choose the screen or window in the KDE portal dialog, confirm on the TV if asked.

Miracast uses Wi-Fi Direct and does not need a router. Your Wi-Fi may blink for a second while it negotiates.

Firewall: `gnome-network-displays` ships its own firewalld zone (`P2P-WiFi-Display`) that it applies automatically to the Wi-Fi Direct link. A `firewall-cmd --reload` after installing is enough to load it. Chromecast additionally needs `mdns` and `8008-8009/tcp` in your normal zone.

For just playing a file or YouTube link on a Chromecast without mirroring:

```bash
catt cast movie.mp4
catt cast https://youtu.be/...
```

---

## 4. Receiving screens

There is **no working Miracast receiver for Linux** today (miraclecast is abandoned), so Windows "Connect to a wireless display" and Samsung *wireless* DeX cannot target a Linux laptop. Everything else is covered:

| Source | Tool | How |
|---|---|---|
| iPhone / iPad / Mac | UxPlay | **Wireless Display → AirPlay receiver**, then pick the laptop in Screen Mirroring on the Apple device |
| Android / Samsung phone | scrcpy | **Mirror phone** asks how the phone is reachable: USB cable, Wi-Fi (picks phones seen on the hotspot or by mDNS, or an IP you type), or Android 11+ *Wireless debugging* pairing code. USB debugging must be on in Developer options. |
| Samsung DeX-style desktop | scrcpy virtual display | **DeX desktop** runs `scrcpy --new-display=1920x1080 --no-vd-system-decorations` |
| Another Windows / Linux / Mac PC | Sunshine on that PC + Moonlight here | **Other PC screen**. Alternative: Deskreen on the other PC and open its URL in a browser here |

UxPlay firewall ports: `7000,7001,7100/tcp` and `6000-6001,7011/udp`.

---

## 5. Wi-Fi hotspot that coexists with your Wi-Fi connection

### The problem

Starting a NetworkManager hotspot on the Wi-Fi interface **replaces** your current Wi-Fi connection: the laptop drops off the internet while hosting. The NetworkManager log says `activated -> deactivating (reason 'new-activation')`.

### The fix: a virtual AP interface on the same channel

Most Intel adapters allow one access point **plus** one client at the same time, as long as both sit on the **same radio channel** and run on **separate interfaces**. Check with:

```bash
iw phy | grep -A6 'valid interface combinations'
```

Look for a line like `#{ managed } <= 2, #{ AP, P2P-client, P2P-GO } <= 1, ... #channels <= 1`.

Set it up:

```bash
# 1. second (virtual) interface in AP mode
sudo iw dev wlp0s20f3 interface add ap0 type __ap

# 2. hotspot profile bound to ap0, shared IPv4 (NAT), trusted firewall zone
nmcli con add type wifi ifname ap0 con-name Display-Hotspot autoconnect no ssid ArchDisplay \
  802-11-wireless.mode ap ipv4.method shared ipv6.method disabled \
  wifi-sec.key-mgmt wpa-psk wifi-sec.psk 'YourPassword' connection.zone trusted

# 3. match the channel of your current Wi-Fi link, then start
ch=$(iw dev wlp0s20f3 info | awk '/channel/{print $2}')
band=$([ "$ch" -gt 14 ] && echo a || echo bg)
nmcli con mod Display-Hotspot 802-11-wireless.band $band 802-11-wireless.channel $ch
nmcli con up Display-Hotspot
```

Result on the test machine: home Wi-Fi on `wlp0s20f3` (channel 149, 80 MHz) and the hotspot on `ap0` (channel 149, 20 MHz), internet intact, guests get internet through NAT, laptop reachable at `10.42.0.1`.

The kit's launcher does steps 1 and 3 automatically every time you press **Start**, and the systemd unit `wifi-ap0.service` recreates `ap0` at boot.

### Firewall zone

The hotspot profile uses `connection.zone trusted`, so joined devices can reach AirPlay, scrcpy and Moonlight without extra rules. NetworkManager's shared mode adds the NAT and DHCP (dnsmasq) itself.

### Caveats

- The hotspot inherits your uplink's band. On a 5 GHz home network some older devices or TVs will not see it. Connect the laptop to a 2.4 GHz network first if that happens.
- If your router changes channel while the hotspot runs, press Stop then Start to resync.
- Sending via Miracast while the hotspot is on may fail (both want the radio). Receiving is fine.

---

## 6. The launchers

### Wireless Display

`~/.local/bin/wireless-display [mode]` — with no argument it opens a Qt window with six big icon buttons; with a mode it runs that mode directly (used by the right-click actions):

| Mode | Does |
|---|---|
| `cast` | `gnome-network-displays` |
| `airplay` | `uxplay -n ArchLaptop` in a Konsole window (close it to stop) |
| `phone` | `scrcpy` in Konsole |
| `dex` | `scrcpy --new-display=1920x1080 --no-vd-system-decorations` |
| `moonlight` | `moonlight` |
| `hotspot` | opens the Wi-Fi Hotspot window |
| `hotspot-start` / `hotspot-stop` / `hotspot-qr` | headless hotspot actions with a kdialog popup |

### Wi-Fi Hotspot

`~/.local/bin/wifi-hotspot-gui` — PyQt6 window:

- Status line (ON/OFF, IP, channel), refreshed every 3 s.
- QR code in the standard `WIFI:T:WPA;S:<ssid>;P:<psk>;;` format; phones join by scanning it.
- **Hide QR / Show QR** also masks the password, so the window is safe to project.
- **Start** / **Stop** (only the applicable one enabled).
- **Change password…** (8–63 chars; restarts the hotspot if it is running).

Both `.desktop` files include `Actions=` so the same functions appear on right-click in the Plasma task manager and app menu.

### Pinning to the taskbar from a script

Plasma exposes its scripting API over D-Bus; this appends a launcher to every task manager:

```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
  for (var p of panels()) for (var w of p.widgets()) {
    if (w.type.indexOf("tasks") === -1) continue;
    w.currentConfigGroup = ["General"];
    var l = w.readConfig("launchers","").split(",").filter(function(s){return s;});
    if (l.indexOf("applications:wifi-hotspot.desktop") === -1) l.push("applications:wifi-hotspot.desktop");
    w.writeConfig("launchers", l.join(","));
  }'
```

---

## 7. File layout

```
wireless-display-kit/
├── install.sh                      # one-shot installer
├── bin/
│   ├── wireless-display            # bash dispatcher (modes + hotspot helpers)
│   ├── wireless-display-gui        # PyQt6 icon-button window
│   └── wifi-hotspot-gui            # PyQt6 hotspot window
├── applications/
│   ├── wireless-display.desktop
│   └── wifi-hotspot.desktop
├── systemd/
│   └── wifi-ap0.service            # recreates the virtual AP interface at boot
└── PROMPT-for-claude.md            # brief for an AI session that publishes this
```

`__WIFI_IF__` and `__HOME__` placeholders in the source files are filled in by `install.sh`.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| TV never appears in Network Displays | Run `gnome-network-displays` from a terminal; check `iw phy` shows P2P modes; make sure firewalld loaded the `P2P-WiFi-Display` zone (`firewall-cmd --get-zones`) |
| "Failed to create avahi client" | `sudo systemctl enable --now avahi-daemon` |
| Chromecast not found | `mdns` service missing in your firewall zone, or different Wi-Fi network |
| Apple device does not see the laptop | UxPlay ports not open, or Avahi down |
| Hotspot start kicks you off Wi-Fi | Profile is bound to the main interface instead of `ap0`; run `nmcli con mod Display-Hotspot connection.interface-name ap0` |
| `ap0` missing after reboot | `systemctl status wifi-ap0.service` |
| Guests have no internet | Check `nft list ruleset | grep masquerade`; NetworkManager adds it for `ipv4.method shared` |

---

## License

MIT. Use, copy, adapt.

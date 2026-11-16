#!/usr/bin/env bash
# Wireless Display Kit installer for Arch Linux + KDE Plasma (Wayland).
# Installs: casting (Miracast/Chromecast), receivers (AirPlay, scrcpy, Moonlight),
# a concurrent Wi-Fi hotspot, and two Plasma launchers with Qt windows.
#
# Usage:  ./install.sh            (interactive, asks before firewall changes)
#         WIFI_IF=wlan0 ./install.sh   (override detected Wi-Fi interface)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" -eq 0 ] && { echo "Run as your normal user, not root (sudo is called when needed)."; exit 1; }

# ---------- 1. detect Wi-Fi interface ----------
WIFI_IF="${WIFI_IF:-$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')}"
[ -n "$WIFI_IF" ] || { echo "No Wi-Fi interface found (NetworkManager required)."; exit 1; }
say "Wi-Fi interface: $WIFI_IF"

# ---------- 2. packages ----------
say "Installing packages from the official repos"
sudo pacman -S --needed --noconfirm \
  pipewire wireplumber xdg-desktop-portal-kde \
  gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav gst-plugin-pipewire \
  intel-media-driver libva-utils iw avahi \
  scrcpy android-tools moonlight-qt \
  kdialog qrencode python-pyqt6

say "Installing AUR packages (gnome-network-displays, uxplay, catt)"
if need yay; then aur=yay; elif need paru; then aur=paru; else
  echo "No AUR helper (yay/paru) found. Install one, or build these manually:"
  echo "  gnome-network-displays  uxplay  catt"; aur=""
fi
[ -n "$aur" ] && $aur -S --needed --noconfirm gnome-network-displays uxplay catt

# ---------- 3. services ----------
say "Enabling Avahi (mDNS, needed for Chromecast and AirPlay discovery)"
sudo systemctl enable --now avahi-daemon

# ---------- 4. firewall (firewalld) ----------
if systemctl is-active --quiet firewalld; then
  say "firewalld is active. Opening the ports the tools need in the public zone"
  echo "  mdns, 8008-8009/tcp (Chromecast), 7000/7001/7100 tcp + 6000-6001/7011 udp (AirPlay)"
  read -rp "Apply these firewall rules now? [Y/n] " a; a=${a:-Y}
  if [[ $a =~ ^[Yy] ]]; then
    sudo firewall-cmd --reload                       # loads the P2P-WiFi-Display zone shipped by gnome-network-displays
    sudo firewall-cmd --permanent --zone=public --add-service=mdns
    sudo firewall-cmd --permanent --zone=public --add-port=8008-8009/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=7000/tcp --add-port=7001/tcp --add-port=7100/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=6000-6001/udp --add-port=7011/udp
    sudo firewall-cmd --reload
  fi
fi

# ---------- 5. launcher scripts and desktop entries ----------
say "Installing launchers to ~/.local/bin and ~/.local/share/applications"
mkdir -p ~/.local/bin ~/.local/share/applications
for f in wireless-display wireless-display-gui wifi-hotspot-gui; do
  sed "s|__WIFI_IF__|$WIFI_IF|g; s|__HOME__|$HOME|g" "$here/bin/$f" > ~/.local/bin/$f
  chmod +x ~/.local/bin/$f
done
for f in wireless-display.desktop wifi-hotspot.desktop; do
  sed "s|__WIFI_IF__|$WIFI_IF|g; s|__HOME__|$HOME|g" "$here/applications/$f" > ~/.local/share/applications/$f
done
need desktop-file-validate && desktop-file-validate ~/.local/share/applications/wireless-display.desktop ~/.local/share/applications/wifi-hotspot.desktop || true
need kbuildsycoca6 && kbuildsycoca6 >/dev/null 2>&1 || true

# ---------- 6. hotspot profile + virtual AP interface ----------
say "Creating the hotspot profile 'Display-Hotspot' (SSID ArchDisplay) on virtual interface ap0"
if ! nmcli -t -f NAME con show | grep -qx Display-Hotspot; then
  pw=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 12)
  nmcli con add type wifi ifname ap0 con-name Display-Hotspot autoconnect no ssid ArchDisplay \
    802-11-wireless.mode ap 802-11-wireless.band bg 802-11-wireless.channel 6 \
    ipv4.method shared ipv6.method disabled \
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pw" connection.zone trusted >/dev/null
  echo "  A random password was generated. See it with:  nmcli -s -g 802-11-wireless-security.psk con show Display-Hotspot"
  echo "  or change it in the Wi-Fi Hotspot window."
else
  echo "  Profile already exists, left unchanged."
fi
sed "s|__WIFI_IF__|$WIFI_IF|g" "$here/systemd/wifi-ap0.service" | sudo tee /etc/systemd/system/wifi-ap0.service >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-ap0.service

# ---------- 7. pin to Plasma taskbar (optional) ----------
if need qdbus6 && qdbus6 org.kde.plasmashell >/dev/null 2>&1; then
  read -rp "Pin 'Wireless Display' and 'Wi-Fi Hotspot' to the Plasma taskbar? [Y/n] " a; a=${a:-Y}
  if [[ $a =~ ^[Yy] ]]; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
      var want = ["applications:wireless-display.desktop","applications:wifi-hotspot.desktop"];
      for (var p of panels()) for (var w of p.widgets()) {
        if (w.type.indexOf("tasks") === -1) continue;
        w.currentConfigGroup = ["General"];
        var l = w.readConfig("launchers","").split(",").filter(function(s){return s;});
        for (var t of want) if (l.indexOf(t) === -1) l.push(t);
        w.writeConfig("launchers", l.join(","));
      }' >/dev/null
  fi
fi

say "Done."
cat <<EOF
  Launchers:  Wireless Display  (cast, AirPlay, phone mirror, DeX, Moonlight, hotspot)
              Wi-Fi Hotspot     (QR code, start/stop, change password)
  Check Wi-Fi Direct support:   iw phy | grep -E 'P2P|\* AP'
  Hotspot password:             nmcli -s -g 802-11-wireless-security.psk con show Display-Hotspot
EOF

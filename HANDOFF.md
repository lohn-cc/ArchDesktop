# Handoff: Arch laptop tuning + Antigravity launchers

Written 2026-11-14, just before a reboot; updated 2026-11-16. Read this first.
For the 2026-11-14 tuning, continue from "Next steps after reboot". For the
latest work, see "Update 2026-11-16".

## Machine

- Lenovo laptop, hostname `lohncc`, Intel Core Ultra 7 255H, 30 GB RAM, Intel graphics
- Arch Linux, KDE Plasma 6.8 on Wayland, zsh, AUR helper `yay`
- 1 TB NVMe: `/boot` (FAT, 1 GB) + LUKS2 volume `root` holding btrfs
  (subvolumes `@`, `@home`, `@log`, `@pkg`)
- Boots with systemd-boot using unified kernel images (UKI) built by mkinitcpio,
  `encrypt` hook, kernel command line in `/etc/kernel/cmdline`
- `sudo` asks for fingerprint, then password (NOPASSWD removed 2026-11-16, see `fingerprint-auth/`)

## Done in the previous session

### Launchers (user level, no reboot needed)

| File | Purpose |
|---|---|
| `~/.local/share/applications/antigravity.desktop` | Antigravity (agent app), handles `antigravity://` |
| `~/.local/share/applications/antigravity-ide.desktop` | Antigravity IDE, with "New Empty Window" action |
| `~/.local/share/applications/antigravity-ide-url-handler.desktop` | hidden, handles `antigravity-ide://` |
| `~/.local/share/icons/hicolor/*/apps/antigravity{,-ide}.png` | icons, 48 to 512 px |

Install locations: `~/.local/share/Antigravity-x64/` (v2.31.1, Electron) and
`~/.local/share/Antigravity IDE/` (VS Code fork 1.107). CLI `agy` is in `~/.local/bin`.

Not yet tested: launching each app from the menu and checking that its window
groups under the pinned icon. If a window shows a generic icon, the
`StartupWMClass` value in the `.desktop` file needs to match the window's app id.

`~/.zshrc`: PATH deduplicated, `antigravity-ide` tab completion added.
Backup: `~/.zshrc.bak-2026-11-14`.

### System changes

| Area | Change | Files |
|---|---|---|
| Snapshots | snapper + snap-pac, pre/post snapshot of `/` per pacman transaction, keep 10, timeline off. Baseline is snapshot #1. `/home` not covered. | `/etc/snapper/configs/root`, `/.snapshots` |
| TRIM | `:allow-discards` added to `cryptdevice=`; `fstrim.timer` enabled. **Needs the reboot to take effect.** | `/etc/kernel/cmdline` (backup `/etc/kernel/cmdline.bak-2026-11-14`) |
| Scrub | `btrfs-scrub@-.timer` enabled (monthly) | |
| Pacman upkeep | `pacman-contrib` + `reflector`; `paccache.timer` and `reflector.timer` enabled; yay build cache cleared | `/etc/xdg/reflector/reflector.conf`, backup `/etc/pacman.d/mirrorlist.bak-2026-11-14` |
| Fallback kernel | `linux-lts` 6.18 installed as UKI `arch-linux-lts.efi`; mainline stays default | `/etc/mkinitcpio.d/linux-lts.preset` |
| Firmware | `fwupd` installed; reported no updatable devices | |
| zram | 4 GB to `ram / 2` (15.4 GB), swappiness 180 etc. Already live. | `/etc/systemd/zram-generator.conf`, `/etc/sysctl.d/99-zram.conf` |
| Battery | charge stops at 80% | `/etc/udev/rules.d/90-battery-charge-limit.rules` |

## Next steps after reboot

1. **If the normal boot entry fails:** choose `arch-linux-backup.efi` in the boot
   menu. It is the previous boot image with the old command line (no discards).
   Then restore `/etc/kernel/cmdline` from its backup and run `sudo mkinitcpio -P`.
2. Confirm TRIM works:
   ```
   lsblk -D /dev/nvme0n1        # the "root" row should no longer show 0B
   sudo fstrim -v /
   ```
3. Once boot is confirmed good, remove the backup image:
   ```
   sudo rm /boot/EFI/Linux/arch-linux-backup.efi
   ```
4. Confirm the settings survived the reboot:
   ```
   swapon --show                                              # ~15.4G zram
   cat /sys/class/power_supply/BAT0/charge_control_end_threshold   # 80
   systemctl --failed
   systemctl list-timers | grep -E "fstrim|paccache|reflector|snapper|scrub"
   ```
5. Launch Antigravity and Antigravity IDE from the app menu; check icons and
   window grouping (see "Not yet tested" above).
6. Apply the 3 pending updates (`yay`), then check `snapper -c root list` shows a
   new pre/post pair, which proves snap-pac works.

## Open items, not started

- Review 21 orphan packages (`pacman -Qdt`): mostly build tools (rust, go, cmake,
  gn, electron42, yarn, nvm). Not removed because some may be used directly.
- Stale firmware boot entries for Windows and Fedora (`efibootmgr`); harmless.
- Optionally test-boot the LTS entry once to be sure the fallback really works.
- No backup of `/home` exists; snapshots of `/` are not a backup.
- Boot log noise that was left alone: i915 "GSC proxy" errors and touchpad
  "touch jump" messages.

## How to continue in the Claude desktop app

Open the folder `/home/lohn/Dev/ThisHost` in the desktop app's Code tab and send:

> Read HANDOFF.md and continue from "Next steps after reboot".

In a terminal instead: `cd ~/Dev/ThisHost && claude --continue` resumes the
original session with full history.

## Update 2026-11-16: authentication, repo, wireless display

This folder is now the git repo for <https://github.com/lohn-cc/ArchDesktop>
(private, branch `main`, git uses `gh` for credentials). Each kit folder has
its own README with the full details; this is the summary.

### Fingerprint authentication (`fingerprint-auth/`)

| Surface | Behaviour | Changed |
|---|---|---|
| Login + lock screen | Fingerprint via Plasma's vendor `kde-fingerprint` stack | nothing (already worked) |
| Polkit dialogs / `pkexec` | Finger first, `timeout=15 max-tries=2`, then password | `/etc/pam.d/polkit-1` (copy of vendor file + one line) |
| `sudo` | Finger first, 30 s, then password; 15 min cache per terminal | `/etc/pam.d/sudo` (backup `sudo.bak-fprintd`) |
| sudoers | `lohn ALL=(ALL:ALL) ALL`. **The old `%wheel NOPASSWD: ALL` rule is gone** (backup `/root/00_lohn.bak-nopasswd`) | `/etc/sudoers.d/00_lohn` |
| KWallet | Disabled (`Enabled=false`); wallet file left on disk | `~/.config/kwalletrc` |

Sensor: Synaptics 06cb:00f9, match-on-chip. Enrolled: both thumbs and both
index fingers, the index fingers labelled `*-middle-finger` (cosmetic, left as is).

Things that bit us, so you do not repeat them:

- `NOPASSWD` made `sudo -v` pass with no auth at all, which looked exactly like
  a working fingerprint. Check `sudo -K; sudo -n true` fails before trusting a test.
- Run one `fprintd-*` command at a time; a second one gets "Device was already claimed".
- `enroll-duplicate` = that finger is already enrolled under another name.
- sudo's auth cache is per terminal; a prompt in one tab is not unlocked by
  authenticating in another. The Claude terminal tabs timed out repeatedly
  this way; run sudo steps in your own terminal.

### Wireless display kit (`wireless-display-kit/`)

- "Mirror phone" / "DeX desktop" failed with `Could not find any ADB device`
  because they ran bare `scrcpy`. Both now go through a connection step: icon
  chooser (USB cable / Wi-Fi / Pair with code) with a Back button; Wi-Fi lists
  phones seen on the hotspot or via adb mDNS; pairing supports Android 11+
  Wireless debugging.
- `android-udev` installed and added to `install.sh`.
- Installed copies in `~/.local/bin` match the repo (`WIFI_IF=wlp0s20f3` substituted).
- **Not yet tested with a real phone.** First test: USB debugging on, plug in,
  Mirror phone -> USB cable, tap Allow on the phone.

### Still open (carried over)

- Items under "Open items, not started" above are unchanged.
- Phone mirror end-to-end test (see above).


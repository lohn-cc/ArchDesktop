# Fingerprint authentication (fprintd + PAM) on Arch / KDE Plasma

Reproducible setup captured from `lohncc` on 2026-11-16. Run `./install.sh`
on a new machine (add `--enroll` to enroll fingers in the same go).

## What it configures

| Area | Behaviour | File |
|---|---|---|
| Login screen, lock screen | Fingerprint via Plasma's vendor `kde-fingerprint` stack. Nothing to configure; active as soon as a finger is enrolled. | `/usr/lib/pam.d/kde-fingerprint` (vendor, untouched) |
| Polkit (KDE "Authentication Required" dialogs, `pkexec`) | Finger first, 15 s timeout, 2 tries, then password | `etc/pam.d/polkit-1` |
| `sudo` | Finger first, 30 s timeout, then password. 15 min cache per terminal. | `etc/pam.d/sudo` |
| sudoers | Normal rule for the user. **Replaces `NOPASSWD: ALL`**, which silently defeats every auth method. | `etc/sudoers.d/00_lohn` |
| KWallet | Disabled. Its key derives from the password, so fingerprint login would leave it locked and prompt anyway. | `home/.config/kwalletrc` |

`su` is left alone on purpose (authenticates as root, not as the user).

## Hardware on lohncc

Synaptics `06cb:00f9` (match-on-chip, "press" type). Driver `synaptics` in
libfprint 1.94.x. Templates live in `/var/lib/fprint/<user>/synaptics/<serial>/`
as small reference files; the actual prints are on the sensor.

## Enrollment

```
fprintd-enroll -f right-index-finger     # repeat touches until "enroll-completed"
fprintd-list "$USER"
fprintd-verify -f any                    # touch: expect "verify-match"
fprintd-delete "$USER"                   # wipe all (also clears the chip)
```

Finger names: `{left,right}-{thumb,index-finger,middle-finger,ring-finger,little-finger}`.

### Fixing the mislabelled index fingers on lohncc

On lohncc the entries named `left-middle-finger` and `right-middle-finger` were
enrolled with the **index** fingers (confirmed with `fprintd-verify -f
right-middle-finger` matching the right index). Auth works regardless; do this
only to make the labels right and add the real middle fingers.

Run one command at a time and wait for `enroll-completed` (or the delete to
return) before the next, otherwise the second one fails with
`Device was already claimed`.

```
# 1. remove the two mislabelled entries (the chip template is deleted too)
fprintd-delete "$USER" -f right-middle-finger
fprintd-delete "$USER" -f left-middle-finger

# 2. enroll index fingers under their real names (6-8 touches each, vary the angle)
fprintd-enroll -f right-index-finger
fprintd-enroll -f left-index-finger

# 3. optional: add the real middle fingers
fprintd-enroll -f right-middle-finger
fprintd-enroll -f left-middle-finger

# 4. check
fprintd-list "$USER"          # expect thumbs + index (+ middle) with correct names
fprintd-verify -f any         # touch an index finger: verify-match
```

If step 2 says `enroll-duplicate`, step 1 did not remove the template: list
with `fprintd-list "$USER"`, delete again, and if the chip still refuses,
wipe everything with `fprintd-delete "$USER"` and re-enroll all fingers.
Nothing else needs changing; PAM only asks the sensor for *a* match.

## Lessons learned (so the next setup is faster)

- **Check sudoers before testing sudo.** A `NOPASSWD` rule makes `sudo -v`
  succeed with no auth at all, which looks exactly like a passing fingerprint.
  Verify with `sudo -K; sudo -n true` -- it must *fail* with "a password is required".
- **One fingerprint client at a time.** Two `fprintd-enroll`/`verify` at once
  gives `Device was already claimed` in `journalctl -u fprintd` and the second
  one does nothing.
- `enroll-duplicate` means the chip already holds that finger under another
  name. The name is only a label; auth works regardless. Re-enroll only if you
  care about the label.
- `pam_fprintd` options: `timeout=N` (min 10) and `max-tries=N`. Default is 30 s / 3.
- `/etc/pam.d/polkit-1` shadows `/usr/lib/pam.d/polkit-1`; package updates to
  the vendor copy do not reach it.
- Fingerprint failures in the Plasma stack do not count toward `pam_faillock`
  (its stack only has `preauth`); wrong passwords do (3 in 15 min -> 10 min lock).
- sudo's credential cache is per terminal. Authenticating in one window does
  not unlock a prompt waiting in another.

## Verify after install

```
sudo -K && sudo -n true      # must fail: "a password is required"
sudo -v                      # finger prompt -> OK
pkexec true                  # KDE dialog -> finger
journalctl -u fprintd -b     # no errors besides occasional "transfer timed out"
```

## Revert

```
sudo cp /etc/pam.d/sudo.bak-fprintd /etc/pam.d/sudo
sudo rm /etc/pam.d/polkit-1                 # falls back to vendor file
sed -i 's/Enabled=false/Enabled=true/' ~/.config/kwalletrc
```

#!/usr/bin/env bash
# Fingerprint authentication for Arch + KDE Plasma (fprintd + pam_fprintd).
# Idempotent. Run as the normal user; it uses sudo where needed.
#
#   ./install.sh            # install packages, PAM, sudoers, disable KWallet
#   ./install.sh --enroll   # same, then enroll fingers interactively
set -euo pipefail
cd "$(dirname "$0")"
USER_NAME="${SUDO_USER:-$USER}"

say() { printf '\n==> %s\n' "$*"; }

say "Packages"
sudo pacman -S --needed --noconfirm fprintd libfprint usbutils

say "Sensor check"
if ! lsusb | grep -qiE 'synaptics|goodix|elan|validity|fingerprint|06cb:|27c6:|04f3:|138a:'; then
  echo "No known fingerprint reader on USB. Check 'lsusb' and libfprint's supported list." >&2
  echo "Continuing anyway; PAM lines are harmless without a device (pam_fprintd just fails -> password)." >&2
fi

say "PAM: sudo and polkit (fingerprint first, password fallback)"
[ -f /etc/pam.d/sudo.bak-fprintd ] || sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak-fprintd
sudo install -m 0644 -o root -g root etc/pam.d/sudo     /etc/pam.d/sudo
sudo install -m 0644 -o root -g root etc/pam.d/polkit-1 /etc/pam.d/polkit-1

say "sudoers: password/fingerprint required (replaces any NOPASSWD rule for this user)"
sed "s/^lohn /${USER_NAME} /" etc/sudoers.d/00_lohn > /tmp/00_user.$$
sudo visudo -c -q -f /tmp/00_user.$$
sudo install -m 0440 -o root -g root /tmp/00_user.$$ "/etc/sudoers.d/00_${USER_NAME}"
rm -f /tmp/00_user.$$
# remove other NOPASSWD grants for wheel so the new rule actually applies
for f in /etc/sudoers.d/*; do
  [ "$f" = "/etc/sudoers.d/00_${USER_NAME}" ] && continue
  if sudo grep -qE '^\s*%wheel.*NOPASSWD' "$f" 2>/dev/null; then
    echo "   NOPASSWD wheel rule found in $f -- commenting it out"
    sudo sed -i -E 's/^(\s*%wheel.*NOPASSWD.*)$/# \1/' "$f"
  fi
done
sudo visudo -c -q

say "KWallet: disable (cannot be unlocked by fingerprint)"
install -Dm0644 home/.config/kwalletrc "$HOME/.config/kwalletrc"
kquitapp6 kwalletd6 2>/dev/null || pkill -x kwalletd6 2>/dev/null || true

if [ "${1:-}" = "--enroll" ]; then
  say "Enroll (one finger at a time; touch repeatedly until 'enroll-completed')"
  for f in right-index-finger left-index-finger right-thumb left-thumb; do
    fprintd-enroll -f "$f" || true
  done
fi

say "Status"
fprintd-list "$USER_NAME" || true
echo
echo "Done. Test:  sudo -K && sudo -v        (finger prompt, then password fallback)"
echo "             pkexec true               (KDE auth dialog)"
echo "Login and lock screen use Plasma's own kde-fingerprint PAM stack automatically."
